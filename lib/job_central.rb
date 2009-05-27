require 'rubygems'
require 'time'
require 'date'
require 'open-uri'
require 'nokogiri'

class JobCentral
  BASE_URI = "http://xmlfeed.jobcentral.com"
  DATE_FORMAT = "%m/%d/%Y %H:%M:%S %p"
  
  def self.parse_date(date)
    DateTime.strptime(date, DATE_FORMAT)
  end
  
  class Employer < Struct.new(:name, :file_uri, :file_size, :date_updated, :jobs)
    def self.all
      @employers = []
      employer_rows = ((html/"table")[-1]/"tr")
      
      employer_rows.each_with_index do |element, idx|
        next unless idx >= 2 # skip header rows
        attributes = element/"td"
        
        employer = Employer.new
        employer.name = attributes[0].text
        employer.file_uri = BASE_URI + (attributes[1]/"a").attr('href')
        employer.file_size = attributes[2].text
        employer.date_updated = JobCentral.parse_date(attributes[3].text)

        @employers << employer
      end
      @employers
    end

    def self.read(uri = BASE_URI + "/index.asp")
      open(uri).read
    end

    def self.html
      Nokogiri::HTML read
    end
    
    def read_jobs
      open(file_uri).read
    end

    def xml
      Nokogiri::XML read_jobs
    end

    def jobs
      @jobs = Job.from_xml(file_uri)
    end
  end

  class Job < Struct.new(:guid, :title, :description, :link, :imagelink, :industries, :expiration_date, :employer_name, :location, :city, :state)

    def self.from_xml(uri)
      xml = Nokogiri::XML open(uri)
      jobs = []
      (xml/"job").each do |element|
        job = Job.new
        job.guid = element.at("guid").text
        job.title = element.at("title").text
        job.description = element.at("description").text
        job.link = element.at("link").text
        job.imagelink = element.at("imagelink").text
        job.expiration_date = Date.parse(element.at("expiration_date").text)
        job.employer_name = element.at("employer").text
        job.location = element.at("location").text
        job.city, job.state = job.location.split(", ")
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
end
