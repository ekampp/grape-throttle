require 'spec_helper'

describe "ThrottleHelper" do
  subject do
    Class.new(Grape::API) do
      use Grape::Middleware::ThrottleMiddleware, cache: Redis.new

      throttle daily: 3
      get('/throttle') do
        "step on it"
      end

      get('/no-throttle') do
        "step on it"
      end

      throttle period: 10.minutes, limit: 3
      get('/throttle-custom-period') do
        "step on it"
      end

      throttle
      get('/wrong-configuration') do
        "step on it"
      end

      throttle period: 2.seconds, limit: 3
      get('/really-short-throttle') do
        "step on it"
      end

      throttle period: 1.minute, limit: Proc.new { 1 }
      get('/throttle-proc-limit') do
        "step on it"
      end

      throttle period: 2.seconds, limit: Proc.new { -1 }
      get('/throttle-proc-limit-disables-throtling') do
        "step on it"
      end
    end
  end

  def app
    subject
  end

  describe "#throttle" do
    it "is not throttled within the rate limit" do
      3.times { get "/throttle" }
      expect(last_response.status).to eq(200)
    end

    it "is throttled beyond the rate limit" do
      4.times { get "/throttle" }
      expect(last_response.status).to eq(429)
    end

    describe "with custom period" do

      it "is not throttled within the rate limit" do
        3.times { get "/throttle-custom-period" }
        expect(last_response.status).to eq(200)
      end

      it "is throttled beyond the rate limit" do
        4.times { get "/throttle-custom-period" }
        expect(last_response.status).to eq(429)
      end

    end

    describe 'proc limit' do

      it "is not throttled within the rate limit" do
        get "/throttle-proc-limit"
        expect(last_response.status).to eq(200)
      end

      it "is throttled beyond the rate limit" do
        2.times { get "/throttle-proc-limit" }
        expect(last_response.status).to eq(429)
      end

      it "is disabled if limit is negative" do
        3.times { get "/throttle-proc-limit-disables-throtling"; sleep 1 }
        expect(last_response.status).to eq(200)
      end

    end

    it "throws an error if period or limit is missing" do
      expect { get("wrong-configuration") }.to raise_exception ArgumentError, 'Please set a period and limit (see documentation)'
    end

    it "only throttles if explicitly specified" do
      expect do
        10.times { get "/no-throttle" }
      end.not_to raise_exception
      expect(last_response.status).to eq(200)
    end

  end

  describe "requests just below the period" do
    it "do not get throttled by the rate limit" do
      4.times do
        get "/really-short-throttle"
        sleep 1
      end

      expect(last_response.status).to eq(200)
    end
  end

  describe 'Redis down' do
    before do
      expect_any_instance_of(Redis).to receive(:ping){ raise Exception }
      allow($stdout).to receive(:write)
    end

    it 'should work when redis is down' do
      get "/throttle"
      expect(last_response.status).to eq(200)
    end

  end
end
