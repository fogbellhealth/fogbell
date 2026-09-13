class CreateRuleReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :rule_reviews do |t|
      t.string :item_id
      t.string :target
      t.string :verdict
      t.text :notes
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.datetime :submitted_at
      t.string :status
      t.datetime :applied_at

      t.timestamps
    end

    add_index :rule_reviews, [ :item_id, :status ]
  end
end
