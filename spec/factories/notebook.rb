FactoryGirl.define do

  factory :notebook do
    guid  '864bb4a6-fa60-4ec8-99b5-77b7fec96930'
    association :user, factory: :user
  end

end