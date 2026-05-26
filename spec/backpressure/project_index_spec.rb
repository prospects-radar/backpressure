# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backpressure::ProjectIndex do
  let(:tmpdir) { Dir.mktmpdir("bp_index") }

  after { FileUtils.remove_entry(tmpdir) }

  before do
    File.write(File.join(tmpdir, "user.rb"), <<~RUBY)
      class User < ApplicationRecord
        has_many :posts
      end
    RUBY

    File.write(File.join(tmpdir, "post.rb"), <<~RUBY)
      class Post < ApplicationRecord
        belongs_to :user
        def publish!
          update!(published: true)
        end
      end
    RUBY

    File.write(File.join(tmpdir, "users_controller.rb"), <<~RUBY)
      class UsersController
        def index
          User.where(active: true)
        end
      end
    RUBY
  end

  subject(:index) { described_class.build(Dir.glob(File.join(tmpdir, "*.rb"))) }

  it "indexes class definitions" do
    classes = index.classes
    expect(classes.map(&:name)).to contain_exactly("User", "Post", "UsersController")
  end

  it "finds classes in a glob pattern" do
    pattern = File.join(tmpdir, "user*.rb")
    matches = index.classes_in(pattern)
    expect(matches.map(&:name)).to contain_exactly("User", "UsersController")
  end

  it "finds classes by name pattern" do
    matches = index.classes_matching(/Controller$/)
    expect(matches.map(&:name)).to eq(["UsersController"])
  end
end

RSpec.describe Backpressure::Contexts::ProjectContext do
  let(:tmpdir) { Dir.mktmpdir("bp_proj") }

  after { FileUtils.remove_entry(tmpdir) }

  it "wraps ProjectIndex and provides file_path" do
    File.write(File.join(tmpdir, "a.rb"), "class A; end")
    files = Dir.glob(File.join(tmpdir, "*.rb"))
    index = Backpressure::ProjectIndex.build(files)
    context = described_class.new(project: index, file_path: files.first)

    expect(context.project).to eq(index)
    expect(context.file_path).to eq(files.first)
  end
end
