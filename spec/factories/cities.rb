FactoryBot.define do
  factory :city do
    slug 'chicago'

    initialize_with { City.instance(slug) }
  end
end
