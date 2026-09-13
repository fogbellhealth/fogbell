# Two orthogonal domains, not a hierarchy — see CLAUDE.md's "Role model" note. Every policy in
# this app answers exactly one question: does this user's role domain cover this area at all.
# There is no per-record nuance beyond that (facility scoping is a separate concern, enforced by
# the controllers building their queries from current_user.facility, not by these policies).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end
end
