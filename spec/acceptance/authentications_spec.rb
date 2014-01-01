require 'spec_helper'
require 'pry'

def logged_in?
    page.has_selector? "a", text: "Logout"
end

feature "Using Login Buttons" do

  background do
    visit root_path
    logged_in?.should == false
  end

  scenario "Evernote signup page should lead to evernote authentication page" do

    OmniAuth.config.add_mock :evernote,
      uid: "472622",
      credentials: {
        token: 'S=s1:U=7362e:E=14972b26f42:C=1421b014346:P=185:A=xrs1133:V=2:H=0f2f663e4716616504563164af1dbf34',
        secret: ''
      }
    OmniAuth.config.add_mock :trello,
      uid: "51487b8b482d0fae5e0017ee",
      credentials: {
        token: 'fbee90bdb3bf1289d18e4b2efbe5101ec6528c558fd29b66e10392933d73563a',
        secret: 'afb2f9289b2c5c43aaab013091fd68fd'
      }
    VCR.use_cassette('authenticate') do
      click_on "Authenticate with Evernote and Trello"
      page.should have_content "Add New Link"
      logged_in?.should == true
    end
  end
end
