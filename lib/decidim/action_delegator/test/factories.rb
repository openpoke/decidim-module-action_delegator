# frozen_string_literal: true

require "decidim/core/test/factories"

FactoryBot.define do
  factory :delegation, class: "Decidim::ActionDelegator::Delegation" do
    setting
    granter { association :user, organization: setting.consultation.organization }
    grantee { association :user, organization: setting.consultation.organization }
  end

  factory :ponderation, class: "Decidim::ActionDelegator::Ponderation" do
    setting
    name { Faker::Lorem.sentence }
    weight { Faker::Number.between(from: 1, to: 10) }
  end

  factory :participant, class: "Decidim::ActionDelegator::Participant" do
    setting
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    ponderation { setting.ponderations.first }
  end

  factory :setting, class: "Decidim::ActionDelegator::Setting" do
    organization { association :organization }
    transient do
      skip_injection { false }
    end

    title { generate_localized_title(:title, skip_injection:) }
    max_grants { 3 }

    trait :with_ponderations do
      after(:create) do |setting|
        create_list(:ponderation, 3, setting: setting)
      end
    end

    trait :with_participants do
      after(:create) do |setting|
        create_list(:participant, 3, setting: setting)
      end
    end
  end
end
