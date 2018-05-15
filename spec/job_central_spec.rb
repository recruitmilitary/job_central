require File.dirname(__FILE__) + '/spec_helper'
require 'byebug'

__DIR__ = File.dirname(__FILE__)

FakeWeb.register_uri(:get, JobCentral::BASE_URI + "/index.asp?authtoken=R2D2",
                     :body => File.read(__DIR__ + "/fixtures/employers.html"))
FakeWeb.register_uri(:get, JobCentral::BASE_URI + "/feeds/1105media.xml?authtoken=R2D2",
                     :body => File.read(__DIR__ + "/fixtures/1105media.xml"))
FakeWeb.register_uri(:get, JobCentral::BASE_URI + "/feeds/1105media-2.xml?authtoken=R2D2",
                     :body => File.read(__DIR__ + "/fixtures/1105media-2.xml"))

JOB_DESCRIPTION = "Job Details\nNew Products Writer\nSend Job to Friend &amp;#187;\nApply Now &amp;#187;\nLocation: Dallas, TX\nDepartment: Editorial\nJob Type: Hire\nOpenings: 0 open, out of 1 available\n\n* \n1105 Media is looking for a detail-oriented New Products Writer in its Dallas, Texas office who can write and edit new products for several B2B magazines.\nPosition Profile:\n\nAs a New Products Writer, you will be responsible for writing 120 to 200 products per month. This requires excellent copyediting and organizational skills and the ability to describe the features and benefits of a product in 80 words or fewer. Occasionally you will be needed to proof articles and pages.\n\nResponsibilities include:\n* Writing 120 to 200 products per month.\n* Copyediting stories and page proofs.\n* Helping the editorial team post products to Web sites.\n* Sending out monthly e-mail blasts for new products.\n* Producing e-newsletters for magazines.\n\nThe ideal candidate for this position will possess the following qualifications:\n* At least one year professional experience, preferably in communications or journalism.\n* BA/BS in Journalism/English/Communications or related field of study.\nExperience in the following areas will be considered a plus:\n* HMTL coding\n* B2B publishing\n* Sitecore CMS\n1105 Media is based in Chatsworth,CA, with primary offices throughtout the United States. The company was formed in April 2006 by Nautic Partners LLC, Alta Communications, and President/CEO Neal Vitale.\nWe offer a competitive salary and a comprehensive benefits package that includes medical/dental/vision insurance, life insurance, disability insurance, 401(k) plan, and a generous paid time off (PTO)/holiday plan.\nWe are an equal opportunity employer.\nSend Job to Friend &amp;#187;\nApply Now &amp;#187;\n"

describe JobCentral do
  before(:each) do
    JobCentral.configure do |config|
      config.auth_token = 'R2D2'
    end
    @employers = JobCentral::Employer.all
  end

  it "returns uri with auth token" do
    employer = @employers.first

    expect(employer.feeds[0]).to eq("#{JobCentral::BASE_URI}/feeds/1105media.xml?authtoken=R2D2")
  end

  it "should fetch the list of employers" do
    @employers.should respond_to(:each)
  end

  it "should parse the format from the feed" do
    JobCentral::Helpers.parse_date("4/12/2009 5:59:01 AM").
      should == DateTime.new(2009, 4, 12, 5, 59, 1)
  end

  describe JobCentral::Employer do
    before(:each) do
      @media = @employers.first
    end

    describe ".parse" do

      let(:error) { OpenURI::HTTPError.new "500 Internal Server Error", "" }

      it 'should retry on errors up to the limit' do
        Kernel.should_receive(:open).exactly(2).times.and_raise(error)
        Kernel.should_receive(:open).once.and_return(File.read(__DIR__ + "/fixtures/employers.html"))
        JobCentral::Employer.parse(JobCentral::BASE_URI + "/index.asp")
      end

      it 'should retry on errors up to the limit and then raise if over' do
        Kernel.stub(:open).and_raise(error)
        expect {
          JobCentral::Employer.parse(JobCentral::BASE_URI + "/index.asp")
        }.to raise_error(OpenURI::HTTPError)
      end

    end

    it "should have attributes parsed from the html" do
      @media.should_not be_nil
      @media.name.should == "1105 Media, Inc."
      @media.feeds.should == ["#{JobCentral::BASE_URI}/feeds/1105media.xml?authtoken=R2D2", "#{JobCentral::BASE_URI}/feeds/1105media-2.xml?authtoken=R2D2"]
      @media.date_updated.should == DateTime.new(2009, 4, 12, 5, 59, 2)
      @media.jobs.should respond_to(:each)
      @media.jobs.size.should == 12 # should span across both feeds
    end

    describe JobCentral::Job do

      describe "#extract_location" do

        it 'stripgs the location of leading spaces / commas' do
          element = double("element", :at => double(:text => ", NY, USA"))
          JobCentral::Job.extract_location(element).should == "NY, USA"
        end

      end

      describe "from xml" do
        before(:each) do
          @jobs = JobCentral::Job.from_xml(JobCentral::BASE_URI + "/feeds/1105media.xml?authtoken=R2D2")
          @writer = @jobs.first
        end

        it "should have attributes parsed from the xml" do
          @writer.guid.should == "1105media-24064"
          @writer.title.should == "New Products Writer"
          @writer.description.should == JOB_DESCRIPTION # check eof
          @writer.link.should == "http://jcnlx.com/3eca112f27834df8b7dbd803d6ecf097105"
          @writer.imagelink.should == "http://images.jobcentral.com/companylogos/1105media.gif"
          @writer.industries.should == ["Media / Publishing"]
          @writer.expiration_date.should == Date.new(2009, 4, 16)
          @writer.employer_name.should == "1105 Media, Inc."
          @writer.location.should == "Dallas, TX, 75219, USA"
          @writer.city.should == "Dallas"
          @writer.state.should == "TX"
          @writer.zip_code.should == "75219"
          @writer.country.should == "USA"
        end
      end

      before(:each) do
        @writer = @media.jobs.first
      end

      it "should have attributes parsed from the xml" do
        @writer.guid.should == "1105media-24064"
        @writer.title.should == "New Products Writer"
        @writer.description.should == JOB_DESCRIPTION # check eof
        @writer.link.should == "http://jcnlx.com/3eca112f27834df8b7dbd803d6ecf097105"
        @writer.imagelink.should == "http://images.jobcentral.com/companylogos/1105media.gif"
        @writer.industries.should == ["Media / Publishing"]
        @writer.expiration_date.should == Date.new(2009, 4, 16)
        @writer.employer_name.should == "1105 Media, Inc."
        @writer.location.should == "Dallas, TX, 75219, USA"
        @writer.city.should == "Dallas"
        @writer.state.should == "TX"
        @writer.zip_code.should == "75219"
        @writer.country.should == "USA"
      end
    end
  end
  { "Dallas, TX, 75219, USA" => {
      :city => "Dallas",
      :state => "TX",
      :zip_code => "75219",
      :country => "USA"
    }, "Darfur, SDN" => {
      :city => nil,
      :state => "Darfur",
      :zip_code => nil,
      :country => "SDN"
    }, ", USA" => {
      :city => nil,
      :state => nil,
      :zip_code => nil,
      :country => "USA"
    }, "US, DC, USA" => {
      :city => "US",
      :state => "DC",
      :zip_code => nil,
      :country => "USA"
    }, ", GA, USA" => {
      :city => nil,
      :state => "GA",
      :zip_code => nil,
      :country => "USA"
    }
  }.each do |string, location|
    it "should parse #{string}" do
      JobCentral::LocationParser.parse(string).should == location
    end
  end

  it 'should return an empty hash when failing to parse' do
    JobCentral::LocationParser.parse("Farmington Hills, OH, MI, 48332, USA").should == {}
  end
end
