FactoryGirl.define do

  factory :trello_auth, class: Authentication do
    user_id      '9999'
    provider     'trello'
    uid          '51487b8b482d0fae5e0017ee'
    token        'fbee90bdb3bf1289d18e4b2efbe5101ec6528c558fd29b66e10392933d73563a'
    token_secret '423b7b79aa632b435dfb20004963f788'
  end

  factory :evernote_auth, class: Authentication do
    user_id      '9999'
    provider     'evernote'
    uid          '472622'
    token        'S=s1:U=7362e:E=14803b5d9d4:C=140ac04add7:P=185:A=xrs1133:V=2:H=8326aa537e688d0c3df0b5e93ad6a97e'
  end

end