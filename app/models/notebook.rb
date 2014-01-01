class Notebook < ActiveRecord::Base
  attr_accessible :name, :guid, :user_id

  validates_uniqueness_of :guid
  validates :user_id, presence: true

  belongs_to :user
  has_many :notebook_boards
  has_many :boards, :through => :notebook_boards

  def self.set_notebook(params, user_id)
    notebook_guid, notebook_name = params.split('|')
    # if notebook exists, use it. If not, create it.
    the_notebook = find_notebook_by_guid notebook_guid
    the_notebook ||= Notebook.create(guid: notebook_guid, name: notebook_name, user_id: user_id)
  end

  def self.find_notebook_by_guid(guid)
    Notebook.where(guid: guid).first
  end

  def self.find_notebooks(nbbs)
    notebooks = []
    nbbs.each do |notebook_board|
      notebooks << Notebook.find(notebook_board.notebook_id)
    end
    notebooks
  end

end
