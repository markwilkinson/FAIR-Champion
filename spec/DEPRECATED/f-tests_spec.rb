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

describe "FTests" do
  context "FAIR CHampion F tests" do

    it 'runs tests' do
      expect("yes").not_to be nil
    end
    it 'F2 test: should find dc in metadata' do
      guid = 'https://w3id.org/a2a-fair-metrics/35-rda-f2-01m-t1-dc/'
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find schema in metadata' do
      guid = 'https://w3id.org/a2a-fair-metrics/36-rda-f2-01m-t1-schema/'
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find dct in metadata' do
      guid = 'https://w3id.org/a2a-fair-metrics/37-rda-f2-01m-t1-dct/'
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find schema with https links' do
      guid = 'https://w3id.org/a2a-fair-metrics/38-rda-f2-01m-t1-schema-https/'
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2 test: should find dcat in metadata' do
      guid = 'https://w3id.org/a2a-fair-metrics/39-rda-f2-01m-t1-dcat/'
      url = RDAF21 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    it 'F2-2 test: negative wrong declared type' do
      guid = 'https://w3id.org/a2a-fair-metrics/40-rda-f2-01m-t2-dc-wrong-type/'
      url = RDAF22 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq -1
    end
    it 'F2-2 test: test of richness of discovery metadata - dcat' do
      guid = 'https://w3id.org/a2a-fair-metrics/41-rda-f2-01m-t2-dct-attributes/'
      url = RDAF23 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'F2-2 test: test of richness of discovery metadata - schema' do
      guid = 'https://w3id.org/a2a-fair-metrics/42-rda-f2-01m-t3-schema-attributes/'
      url = RDAF23 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end
    #50-rda-f1-01m-t1-metadata-pid
    it 'F1-1 test: metadata is a persistent GUID' do
      guid = 'https://w3id.org/a2a-fair-metrics/50-rda-f1-01m-t1-metadata-pid/'
      url = RDAF11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'F1-1 test: metadata is a persistent GUID' do
      guid = 'https://w3id.org/a2a-fair-metrics/51-rda-f1-01m-t1-metadata-no-pid/'
      url = RDAF11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 0
    end

    it 'F1d-1 test: data is a persistent GUID' do
      guid = 'https://w3id.org/a2a-fair-metrics/52-rda-f1-01d-t1-data-pid/'
      url = RDAF11 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end    
    it 'F1 test: signposting record is a persistent GUID' do
      guid = 'https://w3id.org/a2a-fair-metrics/60-rda-f1-01md-t1-citeas-pid/'
      url = RDAF1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 1
    end

    it 'F1d-1 test: data is not a a persistent GUID' do
      guid = 'https://w3id.org/a2a-fair-metrics/53-rda-f1-01d-t1-data-no-pid/'
      url = RDAF1d1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 0
    end
    it 'F1 test: signposting record data is not a a persistent GUID' do
      guid = 'https://w3id.org/a2a-fair-metrics/61-rda-f1-01md-t1-citeas-no-pid/'
      url = RDAF1 + guid
      json = JSON.parse(RestClient.get(url).body)
      expect(json['score']).to eq 0
    end

  end
end
