FactoryGirl.define do

  factory :notebook do
    guid '864bb4a6-fa60-4ec8-99b5-77b7fec96930'
    name 'notebook name'
    association :user, factory: :user
  end

  factory :notebook2, class: Notebook do
    guid 'df6aabad-7ede-4b44-9936-d64e06c70b21'
    name 'notebook2 name'
    association :user, factory: :user
  end

  factory :notebook3, class: Notebook do
    guid '2bf9879c-25c1-427d-9316-9b501f24257f'
    name 'Z test'
    association :user, factory: :user
  end

  factory :notebook4, class: Notebook do
    guid 'c9e72153-5dff-475f-bbea-7b8ab18f6a00'
    name "dmoore5050's notebook"
    association :user, factory: :user
  end

end