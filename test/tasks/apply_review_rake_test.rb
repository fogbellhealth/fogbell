require "test_helper"
require "rake"

class ApplyReviewRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("rulebook:apply_review")
    @task = Rake::Task["rulebook:apply_review"]
    @task.reenable

    @tmp = Dir.mktmpdir("apply-review-rake")
    @git_root = Pathname(@tmp)
    @items_dir = @git_root.join("rulebook")
    @items_dir.mkpath
    FileUtils.cp(file_fixture("rulebook/valid_item.json"), @items_dir.join("X0100.json"))

    system("git", "-C", @tmp, "init", "-q")
    system("git", "-C", @tmp, "-c", "user.email=test@example.test", "-c", "user.name=Test", "commit", "--allow-empty", "-q", "-m", "init")
    system("git", "-C", @tmp, "add", "-A")
    system("git", "-C", @tmp, "-c", "user.email=test@example.test", "-c", "user.name=Test", "commit", "-q", "-m", "seed item")

    @reviewer = create_user(role: "verifier", email: "rake-reviewer@example.test")
    ENV["ITEMS_DIR"] = @items_dir.to_s
    ENV["GIT_ROOT"] = @tmp
    ENV["GIT_CHECK_PATH"] = "rulebook"
  end

  teardown do
    ENV.delete("ITEMS_DIR"); ENV.delete("GIT_ROOT"); ENV.delete("GIT_CHECK_PATH"); ENV.delete("DRY_RUN")
    FileUtils.remove_entry(@tmp)
  end

  test "materializes pending reviews into the item JSON and marks them applied" do
    RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "correct", reviewer: @reviewer)

    @task.invoke

    data = JSON.parse(@items_dir.join("X0100.json").read)
    assert data.dig("supportive_documentation", "federal", 0, "verified_by_expert")
    assert_equal "verified", data.dig("provenance_summary", "expert_review_status")
    assert_equal "applied", RuleReview.find_by(item_id: "X0100").status
  end

  test "DRY_RUN=1 prints the plan and writes nothing" do
    RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "correct", reviewer: @reviewer)
    ENV["DRY_RUN"] = "1"
    original = @items_dir.join("X0100.json").read

    @task.invoke

    assert_equal original, @items_dir.join("X0100.json").read
    assert_equal "pending", RuleReview.find_by(item_id: "X0100").status
  end

  test "refuses to run against an uncommitted rulebook tree" do
    RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "correct", reviewer: @reviewer)
    @items_dir.join("X0100.json").write(@items_dir.join("X0100.json").read.sub("Fog Visibility Check", "Fog Visibility Check (dirty edit)"))

    error = assert_raises(SystemExit) { @task.invoke }
    assert_equal "pending", RuleReview.find_by(item_id: "X0100").status
  end

  test "is idempotent — running again with nothing pending changes nothing" do
    RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "correct", reviewer: @reviewer)
    @task.invoke
    after_first = @items_dir.join("X0100.json").read

    system("git", "-C", @tmp, "add", "-A")
    system("git", "-C", @tmp, "-c", "user.email=test@example.test", "-c", "user.name=Test", "commit", "-q", "-m", "apply review")
    @task.reenable
    @task.invoke

    assert_equal after_first, @items_dir.join("X0100.json").read
  end
end
