class AddRoleAndFacilityToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false
    # Nullable: rulebook-domain users (verifier/staff) have no facility affiliation, by design.
    add_reference :users, :facility, null: true, foreign_key: true
    add_column :users, :dev_both_domains, :boolean, null: false, default: false
  end
end
