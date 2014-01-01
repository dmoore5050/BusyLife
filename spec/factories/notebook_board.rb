FactoryGirl.define do

  factory :notebook_board do
    compiled_update_times "[{\"content\"=>\"Content 1\", \"guid\"=>\"03adc9f2-5564-44cc-9b77-6859ea5f91eb\", \"updated\"=>\"1234567890\"}, {\"content\"=>\"Content 2\", \"guid\"=>\"123456abcdefg\", \"updated\"=>\"1234567089\"}, {\"content\"=>\"Content 3\", \"guid\"=>\"bc8a0d69-9ed4-4fb0-bf0d-dff7733ba705\", \"updated\"=>\"1379951180000\"}]"
    association :user, factory: :user
    association :board, factory: :board
    association :notebook, factory: :notebook
  end

end