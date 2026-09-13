# Synthetic demo fixture — see CLAUDE.md's Data model note. Entirely invented facility, residents
# labeled only by number, no names, no DOBs. Idempotent: clears any previously seeded
# Facility/Resident/Assessment (and the Checks they own) before reseeding, so the worklist stays
# reproducible with `rails db:seed`. Runs one real evidence check per resident (Anthropic API, ~10
# calls) so worklist cards show a genuine model-driven finding, not fabricated text.

FACILITY_NAME = "Harborlight Point Nursing Center"
DEMO_PASSWORD = "fogbell-demo-2026"

DEMO_USERS = [
  { email: "nurse@example.test", role: "nurse", facility: true },
  { email: "verifier@example.test", role: "verifier", facility: false },
  { email: "both@example.test", role: "nurse", facility: true, dev_both_domains: true }
].freeze

# Clean slate: destroy prior seeded users/checks explicitly (by id, captured before destroying the
# assessments/facility that reference them) so a reseed never touches records from real app usage
# or leaves a stale facility_id=nil user behind (Facility's has_many :users is dependent: :nullify,
# not :destroy — nullifying instead of deleting here would leave an invalid row).
User.where(email: DEMO_USERS.map { |u| u[:email] }).destroy_all
old_check_ids = Assessment.joins(:resident).where(residents: { facility: Facility.where(name: FACILITY_NAME) }).pluck(:check_id).compact
Assessment.destroy_all
Resident.destroy_all
Facility.where(name: FACILITY_NAME).destroy_all
Check.where(id: old_check_ids).destroy_all

facility = Facility.create!(name: FACILITY_NAME)

DEMO_USERS.each do |u|
  User.create!(email: u[:email], password: DEMO_PASSWORD, role: u[:role],
               facility: u[:facility] ? facility : nil, dev_both_domains: u.fetch(:dev_both_domains, false))
end
puts "Seeded #{DEMO_USERS.size} demo users (password: #{DEMO_PASSWORD}):"
DEMO_USERS.each { |u| puts "  #{u[:email]} — #{u[:role]}#{' + dev_both_domains (convenience, not a real role)' if u[:dev_both_domains]}" }

today = Date.current

# Each resident's chart_text is a short, focused note set — enough evidence to make one specific
# item's status unambiguous, not a full sprawling chart. lookback_days is 7 for every item chosen
# below (E0800/E0900/E0200/K0710/N0350/O0400/D0500), so the window is always ard-6..ard.
RESIDENTS = [
  {
    label: "Resident 01", assessment_type: "quarterly", ard_offset: 2, focus_item_id: "E0800",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 1 East
      Resident: "Resident 01" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      E0800 Rejection of Care: coded 2 (4-6 days) for the 7-day look-back #{ (ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-5).strftime('%m/%d/%Y')} 08:15  Nursing note — J. Okafor, LPN (day shift)
      Resident refused morning insulin and AM care x2 attempts, stating "leave me alone." Reattempted 30 min later, accepted care. MD aware.

      #{(ard-3).strftime('%m/%d/%Y')} 20:40  Nursing note — M. Pelletier, RN (evening shift)
      Refused evening medications and refused repositioning for 20 minutes. Eventually allowed care after distraction with television.

      #{(ard-1).strftime('%m/%d/%Y')} 09:05  Nursing note — J. Okafor, LPN (day shift)
      Refused shower and AM medications again this morning. Care plan reviewed with resident; declined to discuss reasons.

      === MEDICATION ADMINISTRATION RECORD — EXCERPT ===
      #{(ard-5).strftime('%m/%d')}  0800 REFUSED (JO)   #{(ard-3).strftime('%m/%d')}  2000 REFUSED (MP)   #{(ard-1).strftime('%m/%d')}  0800 REFUSED (JO)
    TXT
    }
  },
  {
    label: "Resident 02", assessment_type: "quarterly", ard_offset: 5, focus_item_id: "E0900",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 2 West
      Resident: "Resident 02" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      E0900 Wandering: coded 1 (1-3 days) for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-2).strftime('%m/%d/%Y')} 03:10  Nursing note — A. Thibodeau, RN (night shift)
      Resident found at 0300 in the day room, stated "looking for the bus stop." Redirected back to room without difficulty. Bed alarm functioning.

      === OTHER RECORDS ===
      No other progress notes, MAR entries, or observations mention wandering, exit-seeking, or disorientation during this look-back period.
    TXT
    }
  },
  {
    label: "Resident 03", assessment_type: "annual", ard_offset: 6, focus_item_id: "E0200",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 1 East
      Resident: "Resident 03" (fictional)
      Assessment type: Annual     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      E0200A Physical behavioral symptoms directed toward others: coded 1 (1-3 days).
      E0200B Verbal behavioral symptoms directed toward others: coded 2 (4-6 days), 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-6).strftime('%m/%d/%Y')} 14:20  Nursing note — J. Okafor, LPN (day shift)
      Resident cursed at CNA during care and called roommate names loudly at lunch. Verbal aggression only, no physical contact.

      #{(ard-4).strftime('%m/%d/%Y')} 21:00  Nursing note — M. Pelletier, RN (evening shift)
      Yelled and swore at staff during evening medication pass. No physical aggression this shift.

      #{(ard-2).strftime('%m/%d/%Y')} 10:30  Nursing note — J. Okafor, LPN (day shift)
      Pushed CNA's arm away during brief change, stated "don't touch me." First physical contact documented this quarter. Verbal cursing continued during care.
    TXT
    }
  },
  {
    label: "Resident 04", assessment_type: "admission", ard_offset: 2, focus_item_id: "K0710",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 2 West
      Resident: "Resident 04" (fictional)
      Assessment type: Admission     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft, prepared by RNAC) ===
      K0710A Percent Intake by Artificial Route: coded 2 (51% or more) for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.
      K0520B Feeding tube: Column 2 (product/method changed) checked.

      === ORDERS ===
      #{(ard-30).strftime('%m/%d/%Y')}  Dr. S. Marchetti (fictional): PEG tube in place, continuous enteral feeding via pump, Jevity 1.5 at 65 mL/hr, standing order — no stop date.

      === PROGRESS NOTES ===
      #{(ard-5).strftime('%m/%d/%Y')} 12:00  Nursing note — J. Okafor, LPN (day shift)
      Resident resting comfortably, PEG site clean and dry, no signs of irritation.

      === MEDICATION/NUTRITION ADMINISTRATION RECORD — EXCERPT ===
      No feeding pump rate, volume infused, or calorie/fluid total is recorded on the MAR or a dietary flow sheet for any day #{(ard-6).strftime('%m/%d')}–#{ard.strftime('%m/%d')}. The standing order states the intended rate; nothing in the chart documents that it was actually delivered, or for how many hours, on any day in this look-back period.
    TXT
    }
  },
  {
    label: "Resident 05", assessment_type: "quarterly", ard_offset: 6, focus_item_id: "N0350",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 1 East
      Resident: "Resident 05" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      N0350A Insulin injections: coded 7 days for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === ORDERS ===
      #{(ard-14).strftime('%m/%d/%Y')}  Dr. S. Marchetti (fictional): Insulin glargine 10 units subcutaneous nightly for type 2 diabetes. Discontinued #{(ard-9).strftime('%m/%d/%Y')} per endocrinology recommendation; resident transitioned to oral metformin only.

      === MEDICATION ADMINISTRATION RECORD — EXCERPT ===
      #{(ard-10).strftime('%m/%d')}  2100 insulin glargine 10 units given (MP)
      #{(ard-9).strftime('%m/%d')}  Insulin glargine DISCONTINUED per order — see orders above
      #{(ard-6).strftime('%m/%d')} through #{ard.strftime('%m/%d')}: metformin 500mg PO BID given daily (JO/MP) — no insulin administration recorded on the MAR for any day in this range.
    TXT
    }
  },
  {
    label: "Resident 06", assessment_type: "significant_change", ard_offset: 4, focus_item_id: "O0400D",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 2 West
      Resident: "Resident 06" (fictional)
      Assessment type: Significant Change in Status     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      O0390D Respiratory Therapy: checked. O0400D Respiratory Therapy days: coded 5 days for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === ORDERS ===
      #{(ard-20).strftime('%m/%d/%Y')}  Dr. S. Marchetti (fictional): Nebulizer treatment (albuterol) 20 minutes BID for COPD.

      === RESPIRATORY THERAPY LOG — EXCERPT ===
      #{(ard-6).strftime('%m/%d/%Y')}  Nebulizer treatment, 20 min, administered by RT — B. Fontaine, RRT (fictional)
      #{(ard-5).strftime('%m/%d/%Y')}  Nebulizer treatment, 20 min — B. Fontaine, RRT
      #{(ard-4).strftime('%m/%d/%Y')}  Nebulizer treatment, 20 min — B. Fontaine, RRT
      #{(ard-2).strftime('%m/%d/%Y')}  Nebulizer treatment, 20 min — B. Fontaine, RRT
      #{(ard-1).strftime('%m/%d/%Y')}  Nebulizer treatment, 20 min — B. Fontaine, RRT
      #{(ard-3).strftime('%m/%d/%Y')}  No treatment recorded (resident at outside appointment).
      #{ard.strftime('%m/%d/%Y')}  No treatment recorded yet today.
    TXT
    }
  },
  {
    label: "Resident 07", assessment_type: "quarterly", ard_offset: 1, focus_item_id: "D0500",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 1 East
      Resident: "Resident 07" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      D0500 Staff Assessment of Resident Mood, item scores total 14 (moderately severe), 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-5).strftime('%m/%d/%Y')} 09:00  Nursing note — J. Okafor, LPN (day shift)
      Resident up in wheelchair, participated in morning activities. No mood concerns noted.

      #{(ard-2).strftime('%m/%d/%Y')} 19:30  Nursing note — M. Pelletier, RN (evening shift)
      Ate well at dinner, watched TV with peers. Pleasant interaction with staff.

      === OTHER RECORDS ===
      No nursing note, social work note, or staff observation in this look-back period documents little interest, sad affect, appetite change, sleep disturbance, or any other mood symptom. The coding worksheet's total score of 14 has no supporting observation in the chart.
    TXT
    }
  },
  {
    label: "Resident 08", assessment_type: "quarterly", ard_offset: -1, focus_item_id: "E0800",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 2 West
      Resident: "Resident 08" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')} (window closed)

      === MDS CODING WORKSHEET (final) ===
      E0800 Rejection of Care: coded 0 (behavior not exhibited) for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-4).strftime('%m/%d/%Y')} 10:00  Nursing note — J. Okafor, LPN (day shift)
      Resident cooperative with all care this shift, no refusals.

      #{(ard-1).strftime('%m/%d/%Y')} 20:00  Nursing note — M. Pelletier, RN (evening shift)
      Accepted all medications and care willingly.
    TXT
    }
  },
  {
    label: "Resident 09", assessment_type: "quarterly", ard_offset: 3, focus_item_id: "K0710",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 1 East
      Resident: "Resident 09" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      K0710B Average fluid intake per day by IV or tube feeding: coded 2 (501cc or more) for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-3).strftime('%m/%d/%Y')} 14:00  Nursing note — J. Okafor, LPN (day shift)
      Tube feeding via PEG administered per pump, 750cc free water flush given this shift. Resident tolerated well, no distension.

      === MEDICATION/NUTRITION ADMINISTRATION RECORD — EXCERPT ===
      Only one shift (#{(ard-3).strftime('%m/%d')}) has a documented tube feeding/IV fluid entry in this look-back period; no other day in the 7-day window has a corresponding note or MAR entry.
    TXT
    }
  },
  {
    label: "Resident 10", assessment_type: "quarterly", ard_offset: 7, focus_item_id: "E0900",
    chart: ->(ard) { <<~TXT
      SYNTHETIC DEMONSTRATION RECORD — NOT A REAL RESIDENT
      Facility: #{FACILITY_NAME} (fictional), Unit 2 West
      Resident: "Resident 10" (fictional)
      Assessment type: OBRA Quarterly     ARD: #{ard.strftime('%m/%d/%Y')}

      === MDS CODING WORKSHEET (draft) ===
      E0900 Wandering: coded 2 (4-6 days) for the 7-day look-back #{(ard-6).strftime('%m/%d')}-#{ard.strftime('%m/%d')}.

      === PROGRESS NOTES ===
      #{(ard-6).strftime('%m/%d/%Y')} 02:40  Nursing note — A. Thibodeau, RN (night shift)
      Found ambulating in hallway at 0230, redirected to room. Bed alarm sounding as designed.

      #{(ard-4).strftime('%m/%d/%Y')} 03:15  Nursing note — A. Thibodeau, RN (night shift)
      Found in another resident's doorway, redirected without incident.

      #{(ard-2).strftime('%m/%d/%Y')} 01:50  Nursing note — A. Thibodeau, RN (night shift)
      Ambulating in hallway again overnight, states "looking for my wife." Redirected, bed alarm in place.

      #{ard.strftime('%m/%d/%Y')} 03:00  Nursing note — A. Thibodeau, RN (night shift)
      Fourth overnight wandering episode this week, found near exit door. Redirected. Care plan updated for increased overnight rounding.
    TXT
    }
  }
].freeze

puts "Seeding #{FACILITY_NAME} with #{RESIDENTS.size} synthetic residents..."

RESIDENTS.each do |r|
  ard = today + r[:ard_offset]
  chart_text = r[:chart].call(ard)
  resident = facility.residents.create!(label: r[:label], chart_text: chart_text)
  status = ard >= today ? "open" : "closed"

  check = Check.create!(chart_text: chart_text, ard: ard, item_ids: [ r[:focus_item_id] ])
  assessment = resident.assessments.create!(assessment_type: r[:assessment_type], ard: ard, status: status,
                                            focus_item_id: r[:focus_item_id], check: check)

  begin
    check.update!(status: "running")
    result = Fogbell::EvidenceCheck::Runner.new(check).run
    check.update!(status: "done", results: result.items, usage: result.usage.to_h, error: nil)
    puts "  #{r[:label]}: #{r[:focus_item_id]} -> #{result.items.first&.dig('status')} (#{status}, ARD #{ard.iso8601})"
  rescue Fogbell::EvidenceCheck::Error, Fogbell::Pipeline::Error => e
    check.update!(status: "failed", error: e.message)
    puts "  #{r[:label]}: #{r[:focus_item_id]} -> FAILED (#{e.message})"
  end
end

puts "Done. #{Assessment.open_windows.count} open windows, #{Assessment.where(status: 'closed').count} closed."
