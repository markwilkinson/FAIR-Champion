require_relative 'spec_helper'
require "rest-client"
require 'json'

# 10.7910/DVN/FJM7F4

LOCATION = "http://localhost:4567/tests/" # GEN3-RDA-F2-3?guid=10.7910/DVN/Z2JD58"
RDAF1 = LOCATION + "GEN3-RDA-F1-1-2-3-4?guid="
RDAF21 = LOCATION + "GEN3-RDA-F2-1?guid="
RDAF22 = LOCATION + "GEN3-RDA-F2-2?guid="
RDAF23 = LOCATION + "GEN3-RDA-F2-3?guid="
RDAF11 = LOCATION + "GEN3-RDA-F1-1?guid="
RDAF1d1 = LOCATION + "GEN3-RDA-F1d-1?guid="

guid = "10.7910/DVN/FJM7F4"  #@ dataverse
describe "DVTests" do
  context "FAIR CHampion F tests" do

    it 'runs tests' do
      expect("yes").not_to be nil
    end
    it 'F2 test: should find dc in metadata' do
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find schema in metadata' do
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find dct in metadata' do
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find schema with https links' do
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find dcat in metadata' do
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2-2 test: negative wrong declared type' do
      url = RDAF22 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq -1
    end
    it 'F2-2 test: test of richness of discovery metadata - dcat' do
      url = RDAF23 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'F2-2 test: test of richness of discovery metadata - schema' do
      url = RDAF23 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    #50-rda-f1-01m-t1-metadata-pid
    it 'F1-1 test: metadata is a persistent GUID' do
      url = RDAF11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'F1-1 test: metadata is a persistent GUID' do
      url = RDAF11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 0
    end

    it 'F1d-1 test: data is a persistent GUID' do
      url = RDAF11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end    
    it 'F1 test: signposting record is a persistent GUID' do
      url = RDAF1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'F1d-1 test: data is not a a persistent GUID' do
      url = RDAF1d1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 0
    end
    it 'F1 test: signposting record data is not a a persistent GUID' do
      url = RDAF1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 0
    end

  end
end
