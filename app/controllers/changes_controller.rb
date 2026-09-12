# GET /changes -> reverse-chronological feed of detected changes in the corpus's own source
# documents: revision diffs (a document changed between two dated versions) and corpus additions.
class ChangesController < ApplicationController
  def index
    @entries = Fogbell::CorpusChanges.all
  end
end
