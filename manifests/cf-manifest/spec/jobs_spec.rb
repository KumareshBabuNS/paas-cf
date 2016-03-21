RSpec.describe "the global update block" do

  let(:manifest) { manifest_with_defaults }

  describe "in order to run parallel deployment by default" do
    it "has serial false" do
      expect(manifest["update"]["serial"]).to be false
    end
  end

end

RSpec.describe "the jobs definitions block" do

  let(:jobs) { manifest_with_defaults["jobs"] }

  def get_job(job_name)
    jobs.select{ |j| j["name"] == job_name}.first
  end

  def is_serial(job_name)
    job = get_job(job_name)
    job["update"]["serial"]
  end

  def ordered(job1_name, job2_name)
    i1 = jobs.index{ |j| j["name"] == job1_name }
    i2 = jobs.index{ |j| j["name"] == job2_name }
    i1 < i2
  end

  describe "in order to enforce etcd dependency on NATS" do
    it "has etcd_z1 serial" do
      expect(is_serial("etcd_z1")).to be true
    end

    it "has nats_z1 before etcd_z1" do
      expect(ordered("nats_z1", "etcd_z1")).to be true
    end

    it "has nats_z2 before etcd_z1" do
      expect(ordered("nats_z2", "etcd_z1")).to be true
    end
  end

  describe "in order to start one etcd master for consensus" do
    it "has etcd_z1 serial" do
      expect(is_serial("etcd_z1")).to be true
    end

    it "has etcd_z1 before etcd_z2" do
      expect(ordered("etcd_z1", "etcd_z2")).to be true
    end

    it "has etcd_z1 before etcd_z3" do
      expect(ordered("etcd_z1", "etcd_z3")).to be true
    end
  end

  describe "in order to start one consul master for consensus" do
    it "has consul_z1 serial" do
      expect(is_serial("consul_z1")).to be true
    end

    specify "has consul_z1 first" do
      expect(jobs[0]["name"]).to eq("consul_z1")
    end
  end


end