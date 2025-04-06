require 'spec_helper'

RSpec.describe Champion::Core do

  def app
    Champion::ChampionApp.new
  end

  c = Champion::Core.new
  set = "846866256"

  context "initialize" do
    it "returns a Champion::Core object" do
      expect(c).to be_a Champion::Core
    end
  end

  context "run assessment" do
    it "returns a test set result string" do
      r = c.run_assessment(subject: "https://go-fair.org", setid: set)
      expect(r).to be_a String
    end
    it "returns a test set result json string" do
      r = c.run_assessment(subject: "https://go-fair.org", setid: set)
      j = JSON.parse(r)
      expect(j).to be_a JSON
    end
  end

end
