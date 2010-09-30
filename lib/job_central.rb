require 'rubygems'
require 'time'
require 'date'
require 'open-uri'
require 'nokogiri'

module JobCentral

  BASE_URI = "http://xmlfeed.jobcentral.com".freeze

  DATE_FORMAT = "%m/%d/%Y %H:%M:%S %p".freeze

  DEFAULT_RETRY_LIMIT = 3

  RESCUABLE_ERRORS = [OpenURI::HTTPError].freeze

  ParseError = Class.new(StandardError)

  module Helpers

    extend self

    def parse_date(date)
      DateTime.strptime(date, DATE_FORMAT)
    end

    def open(*args, &block)
      Kernel.open(*args, &block)
    rescue OpenURI::HTTPError => e
      retries ||= 0
      if retries < DEFAULT_RETRY_LIMIT
        retries += 1
        retry
      else
        raise e
      end
    end

  end

  class Employer < Struct.new(:name, :date_updated)

    include Helpers
    extend  Helpers

    class << self

      def all
        parse(BASE_URI + "/index.asp")
      end

      def members
        parse(BASE_URI + "/index.asp?member=member")
      end

      def parse(uri)
        html = Nokogiri::HTML open(uri)
        employer_rows = ((html/"table")[-1]/"tr")
        employer_hash = Hash.new { |h, k| h[k] = Employer.new }

        employer_rows.each_with_index do |element, idx|
          next unless idx >= 2 # skip header rows
          attributes = element/"td"
          name = attributes[0].text.strip

          employer = employer_hash[name]
          employer.name = name
          employer.date_updated = [employer.date_updated, parse_date(attributes[3].text)].compact.max
          employer.feeds << BASE_URI + (attributes[1]/"a").attr('href')

        end
        employers = employer_hash.values
        employers.extend Finders
        employers
      end

    end

    def jobs
      feeds.map do |feed|
        Job.from_xml(feed)
      end.flatten
    end

    def feeds
      @feeds ||= []
    end

  end

  module Finders

    def find_by_name(*names)
      select { |employer| names.include?(employer.name) }
    end

  end

  class Job < Struct.new(:guid, :title, :description, :link, :imagelink,
                         :industries, :expiration_date, :employer_name,
                         :location, :city, :state, :zip_code, :country)

    include Helpers
    extend  Helpers

    def self.from_xml(uri)
      xml = Nokogiri::XML open(uri)
      jobs = []
      (xml/"job").each do |element|
        location = element.at("location").text
        parsed_location = LocationParser.parse(location)
        job = Job.new
        job.guid = element.at("guid").text
        job.title = element.at("title").text
        job.description = element.at("description").text
        job.link = element.at("link").text
        job.imagelink = element.at("imagelink").text
        job.expiration_date = Date.parse(element.at("expiration_date").text)
        job.employer_name = element.at("employer").text
        job.location = location
        job.city = parsed_location[:city]
        job.state = parsed_location[:state]
        job.zip_code = parsed_location[:zip_code]
        job.country = parsed_location[:country]
        element.css("industry").each do |industry|
          job.industries << industry.text
        end
        jobs << job
      end
      jobs
    end

    def industries
      @industries ||= []
    end
  end

  class LocationParser
    def self.parse(string)
      parser = new
      parser.parse(string)
    end

    def parse(string)
      pieces = string.split(', ')
      case pieces.size
      when 4
        {
          :city     => parse_piece(pieces[0]),
          :state    => parse_piece(pieces[1]),
          :zip_code => parse_piece(pieces[2]),
          :country  => parse_piece(pieces[3])
        }
      when 3
        {
          :city     => parse_piece(pieces[0]),
          :state    => parse_piece(pieces[1]),
          :zip_code => nil,
          :country  => parse_piece(pieces[2])
        }
      when 2
        {
          :city     => nil,
          :state    => parse_piece(pieces[0]),
          :zip_code => nil,
          :country  => parse_piece(pieces[1])
        }
      else
        {}
      end
    end

    private
    def parse_piece(piece)
      return nil if piece.empty?
      piece
    end
  end
end
