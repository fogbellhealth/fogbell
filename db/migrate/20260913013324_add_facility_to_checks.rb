class AddFacilityToChecks < ActiveRecord::Migration[8.1]
  def change
    # Nullable at the DB level (pre-existing rows have none); the app always sets it going forward
    # so a facility user's checks scope (current_user.facility.checks) can find its own work.
    add_reference :checks, :facility, null: true, foreign_key: true
  end
end
