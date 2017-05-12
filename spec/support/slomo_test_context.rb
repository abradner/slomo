shared_context 'slomo_test' do
  let(:target_app) { double 'Example Rack App' }

  before(:each) do
    allow(target_app).to receive(:call).and_return([200, {}, "ok"])
  end
end
