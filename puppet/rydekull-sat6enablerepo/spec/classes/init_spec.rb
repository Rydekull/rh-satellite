require 'spec_helper'
describe 'sat6enablerepo' do

  context 'with defaults for all parameters' do
    it { should contain_class('sat6enablerepo') }
  end
end
