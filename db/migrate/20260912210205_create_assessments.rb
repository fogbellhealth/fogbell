class CreateAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :assessments do |t|
      t.references :resident, null: false, foreign_key: true
      t.string :assessment_type
      t.date :ard
      t.string :status
      t.string :focus_item_id
      t.references :check, null: true, foreign_key: true

      t.timestamps
    end
  end
end
