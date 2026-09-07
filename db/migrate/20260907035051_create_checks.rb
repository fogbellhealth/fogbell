class CreateChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :checks do |t|
      t.text :chart_text
      t.date :ard
      t.json :item_ids
      t.string :status
      t.json :results
      t.text :error
      t.json :usage

      t.timestamps
    end
  end
end
