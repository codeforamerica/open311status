class CitiesTasks
  include Rake::DSL

  def initialize
    namespace :cities do
      desc 'Load all cities into the database'
      task :load => :environment do |t, args|
        Rails.logger = Logger.new(STDOUT)
        Rails.logger.info "Populating database with cities"
        City.load!
      end

      desc 'Fetch service requests for all cities, or list of individual cities'
      task :service_requests, [:slug] => :environment do |task, args|
        Rails.logger = Logger.new(STDOUT)
        cities = find_cities(args)

        cities.each do |city|
          if ENV['ASYNC'].present?
            FetchServiceRequestsJob.perform_later(city)
          else
            FetchServiceRequestsJob.perform_now(city)
          end
        end
      end

      desc 'Fetch service list/definitions for all cities, or list of individual cities'
      task :service_list, [:slug] => :environment do |task, args|
        Rails.logger = Logger.new(STDOUT)
        cities = find_cities(args)

        cities.each do |city|
          if ENV['ASYNC'].present?
            FetchServiceListJob.perform_later(city)
          else
            FetchServiceListJob.perform_now(city)
          end
        end
      end

      desc 'Fetch all service requests for a given date range (recursively)'
      task :all_service_requests, [:slug] => :environment do |task, args|
        Rails.logger = Logger.new(STDOUT)

        cities = find_cities(args)
        start_at = ENV.fetch('START_AT').to_datetime.beginning_of_day
        end_at = ENV.fetch('END_AT').to_datetime.end_of_day

        cities.each do |city|
          if ENV['ASYNC'].present?
            FetchServiceRequestsRecursivelyJob.perform_later(city, start_at.to_json, end_at.to_json)
          else
            FetchServiceRequestsRecursivelyJob.perform_now(city, start_at.to_json, end_at.to_json)
          end
        end
      end

      desc 'Delete service requests and statuses'
      task cleanup: :environment do |task, args|
        Status.where('created_at < ?', 48.hours.ago).find_each(&:destroy)
        ServiceRequest.where('created_at < ?', 48.hours.ago).find_each(&:destroy)
      end
    end
  end

  private

  def find_cities(args)
    slugs = Array(args[:slug]) + Array(args.extras)

    if slugs.size > 0
      slugs.map { |slug| City.find_by!(slug: slug) }
    else
      City.all
    end
  end
end

CitiesTasks.new