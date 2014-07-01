FactoryGirl.define do

  factory :list do
    guid        '51d6d0ca27a305fa5300590c'
    name        'List Name'
    contents    "[ { \"content\"=>\"name\", \"guid\"=>\"guid\", \"desc\"=>\"desc\" } ]"
    association :board, factory: :board
  end

  factory :list2, class: List do
    guid        '52f005219366c5002d9c2bc9'
    name        'Another List Name'
    contents    "[ { \"content\"=>\"name\", \"guid\"=>\"guid\", \"desc\"=>\"desc\" } ]"
    association :board, factory: :board
  end

end