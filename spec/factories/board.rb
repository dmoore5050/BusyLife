FactoryGirl.define do

  factory :board do
    guid '51d6d0ca27a305fa5300590a'
    association :user, factory: :user
  end

  factory :board2, class: Board do
    guid '51d6d0ca27a305fa5300590b'
    association :user, factory: :user
  end

  factory :board3, class: Board do
    guid '51d6d0ca27a305fa5300590c'
    association :user, factory: :user
  end

end