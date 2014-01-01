FactoryGirl.define do

  factory :board do
    guid '51d6d0ca27a305fa5300590a'
    association :user, factory: :user
  end

end