class CreateResidents < ActiveRecord::Migration[8.1]
  def change
    create_table :residents do |t|
      t.references :facility, null: false, foreign_key: true
      t.string :label
      t.text :chart_text

      t.timestamps
    end
  end
end
