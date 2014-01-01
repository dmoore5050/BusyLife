FactoryGirl.define do

  factory :list do
    guid        '51d6d0ca27a305fa5300590c'
    name        'List Name'
    contents    "[{\"content\"=>\"name\", \"guid\"=>\"guid\"}]"
    association :board, factory: :board
  end

end