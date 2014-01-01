require 'spec_helper'

describe Notebook, 'columns' do
  it { should have_db_column :name }
  it { should have_db_column :guid }
  it { should have_db_column :user_id }
end

describe Notebook, 'validations' do
  it { should validate_uniqueness_of :guid }
  it { should validate_presence_of :user_id }
end

describe Notebook, "associations" do
  it { should belong_to :user }
  it { should have_many :notebook_boards }
  it { should have_many(:boards).through :notebook_boards }
end

describe Notebook, '.set_notebook' do
  it "should create a new Notebook if guid doesn't match" do
    params, user_id = '1|evernoteName', 1
    notebook = Notebook.set_notebook params, user_id
    notebook.name.should eq 'evernoteName'
  end

  it 'should use existing Notebook if guid matches' do
    Notebook.create(guid: '1', name: 'test notebook', user_id: 1)
    params, user_id = '1|evernoteName', 1
    notebook = Notebook.set_notebook params, user_id
    notebook.name.should eq 'test notebook'
  end
end

describe Notebook, '.find_notebook_by_guid' do
  it 'should find notebook if given valid guid' do
    Notebook.create(guid: '1', name: 'test notebook', user_id: 1)
    guid = '1'
    notebook = Notebook.find_notebook_by_guid guid
    notebook.name.should eq 'test notebook'
  end

  it 'should return nil if given invalid guid' do
    guid = '1'
    notebook = Notebook.find_notebook_by_guid guid
    notebook.should eq nil
  end
end