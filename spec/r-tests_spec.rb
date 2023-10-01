require_relative 'spec_helper'
require "rest-client"

LOCATION = "http://localhost:4567/tests/" # GEN3-RDA-F2-3?guid=10.7910/DVN/Z2JD58"
RDAF1 = LOCATION + "GEN3-RDA-F1-2-3-4?guid="
RDAF21 = LOCATION + "GEN3-RDA-F2-1?guid="
RDAF22 = LOCATION + "GEN3-RDA-F2-2?guid="
RDAF23 = LOCATION + "GEN3-RDA-F2-3?guid="
RDAF11 = LOCATION + "GEN3-RDA-F1-1?guid="
RDAF1d1 = LOCATION + "GEN3-RDA-F1d-1?guid="
RDAR11 = LOCATION + "GEN3-RDA-R1-1?guid="
RDAR1t1= LOCATION + "GEN3-RDA-R1-t1?guid="

describe "RTests" do
  context "FAIR Champion R tests" do

    it 'runs tests' do
      expect("yes").not_to be nil
    end
    it 'R1 test: No items means not an About page' do
      guid = 'https://w3id.org/a2a-fair-metrics/54-rda-r1-01m-t4-type/'
      url = RDAR11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'R1 test: about pages must have at least two types' do
      guid = 'https://w3id.org/a2a-fair-metrics/57-rda-r1-01m-t7-type-and-about/'
      url = RDAR11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'R1 test: Pages with items must be AboutPages' do
      guid = 'https://w3id.org/a2a-fair-metrics/58-rda-r1-01m-t7-type-and-no-about/'
      url = RDAR11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq -1
    end

    it 'R1t1 test: All items must have a type' do
      guid = 'https://w3id.org/a2a-fair-metrics/65-rda-r1-01m-t1-item-type/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'R1t1 test: All items must have a type when there are multiple items' do
      guid = 'https://w3id.org/a2a-fair-metrics/66-rda-r1-01m-t1-multiple-item-type/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    
    it 'R1t1 test: test of item types should pass if there are no items' do
      guid = 'https://w3id.org/a2a-fair-metrics/67-rda-r1-01m-t1-no-item/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    
    it 'R1t1 test: test of item types should fail if any item lacks a type' do
      guid = 'https://w3id.org/a2a-fair-metrics/68-rda-r1-01m-t1-some-item-type/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'R1t1 test: test of item types should fail item type declaration is not IANA standard format' do
      guid = 'https://w3id.org/a2a-fair-metrics/69-rda-r1-01m-t2-wrong-type/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq -1
    end

    it 'R1t1 test: test of item types should not fail if item type declaration includes a charset or other claim' do
      guid = 'https://w3id.org/a2a-fair-metrics/70-rda-r1-01m-t2-type-charset/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'R1t1 test: test of item types should not fail if item type is registered in IANA' do
      guid = 'https://w3id.org/a2a-fair-metrics/71-rda-r1-01m-t3-type-registered/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'R1t1 test: test of item types should throw a warning but not fail if item type is NOT registered in IANA, but begins with vnd or priv' do
      guid = 'https://w3id.org/a2a-fair-metrics/72-rda-r1-01m-t4-type-unregistered/'
      url = RDAR1t1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

  end
end
