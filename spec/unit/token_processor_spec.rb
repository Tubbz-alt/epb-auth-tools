# frozen_string_literal: true

require 'token_processor'
require 'token'

describe 'Unit::Auth::TokenProcessor' do
  before do
    @jwt_secret = ENV['JWT_SECRET']
    @jwt_issuer = ENV['JWT_ISSUER']

    @token_processor = Auth::TokenProcessor.new @jwt_secret, @jwt_issuer
    @malformed_token = Base64.encode64 'I am all wrong'
  end

  context 'when a token is valid' do
    it 'does return an instance of Auth::Token' do
      expect(
        @token_processor.process(token_generate(:valid_token))
      ).to be_an_instance_of(Auth::Token)
    end

    it 'does allow checking a scope' do
      expect(
        @token_processor.process(token_generate(:valid_token)).scope?('scope:1')
      ).to be true
      expect(
        @token_processor.process(token_generate(:valid_token)).scope?(
          'does-not-exist'
        )
      ).to be false
    end

    it 'does allow checking a number of scopes' do
      expect(
        @token_processor.process(token_generate(:valid_token)).scopes?(
          %w[scope:1 scope:2]
        )
      ).to be true
      expect(
        @token_processor.process(token_generate(:valid_token)).scope?(
          %w[scope:1 does-not-exist]
        )
      ).to be false
    end
  end

  context 'when a token is not a JWT token' do
    it 'does throw an Auth::Errors::TokenDecodeError Error' do
      expect { @token_processor.process @malformed_token }.to raise_error(
        instance_of(Auth::Errors::TokenDecodeError)
      )
    end
  end

  context 'when a token has a different issuer' do
    it 'does throw an Auth::Errors::TokenIssuerIncorrect Error' do
      expect {
        @token_processor.process token_generate(:incorrect_issuer_token)
      }.to raise_error(instance_of(Auth::Errors::TokenIssuerIncorrect))
    end
  end

  context 'when a token has expired' do
    it 'does throw an Auth::Errors::TokenExpired Error' do
      expect {
        @token_processor.process token_generate(:expired_token)
      }.to raise_error(instance_of(Auth::Errors::TokenExpired))
    end
  end

  context 'when a token was issued in the future' do
    it 'does throw an Auth::Errors::TokenNotYetValid Error' do
      expect {
        @token_processor.process token_generate(:premature_token)
      }.to raise_error(instance_of(Auth::Errors::TokenNotYetValid))
    end
  end

  context 'when a token has not issued at attribute' do
    it 'does throw an Auth::Errors::TokenHasNoIssuedAt Error' do
      expect {
        @token_processor.process token_generate(:missing_issued_at_token)
      }.to raise_error(instance_of(Auth::Errors::TokenHasNoIssuedAt))
    end
  end

  context 'when a token does not have a subject' do
    it 'does throw an Auth::Errors::TokenHasNoSubject Error' do
      expect {
        @token_processor.process token_generate(:missing_sub_token)
      }.to raise_error(instance_of(Auth::Errors::TokenHasNoSubject))
    end
  end

  context 'when a token has been edited after generation' do
    it 'does throw an Auth::Errors::TokenTamperDetected Error' do
      expect {
        jwt = token_generate(:valid_token)
        jwt = jwt.split('.')
        payload = JSON.parse Base64.decode64 jwt[1]
        payload['scopes'] = %w[admin:*]
        jwt[1] = Base64.encode64 payload.to_json

        @token_processor.process jwt.join('.')
      }.to raise_error(instance_of(Auth::Errors::TokenTamperDetected))
    end
  end
end