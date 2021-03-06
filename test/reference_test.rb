# encoding: UTF-8
require File.expand_path "../test_helper", __FILE__

class ReferenceTest < Rugged::TestCase
  include Rugged::RepositoryAccess

  UNICODE_REF_NAME = "A\314\212ngstro\314\210m"

  def test_list_references
    refs = @repo.refs.map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "heads/master:heads/packed:notes/commits:tags/v0.9:tags/v1.0", refs
  end

  def test_can_filter_refs_with_regex
    refs = @repo.refs(/tags/).map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "tags/v0.9:tags/v1.0", refs
  end

  def test_can_filter_refs_with_string
    refs = @repo.refs('0.9').map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "tags/v0.9", refs
  end

  def test_can_open_reference
    ref = Rugged::Reference.lookup(@repo, "refs/heads/master")
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/master", ref.name
  end

  def test_looking_up_missing_ref_returns_nil
    ref = Rugged::Reference.lookup(@repo, "lol/wut")
    assert_equal nil, ref
  end

  def test_load_reflog
    ref = Rugged::Reference.lookup(@repo, "refs/heads/master")
    log = ref.log
    e =  log[1]
    assert_equal e[:id_old], "8496071c1b46c854b31185ea97743be6a8774479"
    assert_equal e[:id_new], "5b5b025afb0b4c913b4c338a42934a3863bf3644"
    assert_equal e[:message], "commit: another commit"
    assert_equal e[:committer][:email], "schacon@gmail.com"
  end

  def test_reference_exists
    exists = Rugged::Reference.exist?(@repo, "refs/heads/master")
    assert exists

    exists = Rugged::Reference.exist?(@repo, "lol/wut")
    assert !exists
  end

  def test_load_packed_ref
    ref = Rugged::Reference.lookup(@repo, "refs/heads/packed")
    assert_equal "41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/packed", ref.name
  end

  def test_resolve_head
    ref = Rugged::Reference.lookup(@repo, "HEAD")
    assert_equal "refs/heads/master", ref.target
    assert_equal :symbolic, ref.type

    head = ref.resolve
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", head.target
    assert_equal :direct, head.type
  end
end

class ReferenceWriteTest < Rugged::TestCase
  include Rugged::TempRepositoryAccess

  def test_list_unicode_refs
    Rugged::Reference.create(@repo,
      "refs/heads/#{ReferenceTest::UNICODE_REF_NAME}",
      "refs/heads/master")

    refs = @repo.refs.map { |r| r.name.gsub("refs/", '') }
    assert refs.include? "heads/#{ReferenceTest::UNICODE_REF_NAME}"
  end

  def test_create_symbolic_ref
    ref = Rugged::Reference.create(@repo, "refs/heads/unit_test", "refs/heads/master")
    assert_equal "refs/heads/master", ref.target
    assert_equal :symbolic, ref.type
    assert_equal "refs/heads/unit_test", ref.name
    ref.delete!
  end

  def test_create_ref_from_oid
    ref = Rugged::Reference.create(@repo,
      "refs/heads/unit_test",
      "36060c58702ed4c2a40832c51758d5344201d89a")

    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/unit_test", ref.name
    ref.delete!
  end

  def test_rename_ref
    ref = Rugged::Reference.create(@repo,
      "refs/heads/unit_test",
      "36060c58702ed4c2a40832c51758d5344201d89a")

    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/unit_test", ref.name

    ref.rename "refs/heads/rug_new_name"
    assert_equal "refs/heads/rug_new_name", ref.name
    ref.delete!
  end

  def test_set_ref_target
    ref = Rugged::Reference.create(@repo,
      "refs/heads/unit_test",
      "36060c58702ed4c2a40832c51758d5344201d89a")

    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/unit_test", ref.name

    ref.target = "5b5b025afb0b4c913b4c338a42934a3863bf3644"
    assert_equal "5b5b025afb0b4c913b4c338a42934a3863bf3644", ref.target
    ref.delete!
  end

  def test_write_and_read_unicode_refs
    ref1 = Rugged::Reference.create(@repo, "refs/heads/Ångström", "refs/heads/master")
    ref2 = Rugged::Reference.create(@repo, "refs/heads/foobar", "refs/heads/Ångström")

    assert_equal "refs/heads/Ångström", ref1.name
    assert_equal "refs/heads/Ångström", ref2.target
  end
end

class ReflogTest < Rugged::TestCase
  include Rugged::TempRepositoryAccess

  def setup
    super
    @ref = Rugged::Reference.create(@repo,
      "refs/heads/test-reflog",
      "36060c58702ed4c2a40832c51758d5344201d89a")
  end

  def test_create_reflog_entries
    @ref.log!({ :name => "foo", :email => "foo@bar", :time => Time.now })
    @ref.log!({ :name => "foo", :email => "foo@bar", :time => Time.now }, "commit: bla bla")

    reflog = @ref.log
    assert_equal reflog.size, 2

    assert_equal reflog[0][:id_old], "0000000000000000000000000000000000000000"
    assert_equal reflog[0][:id_new], "36060c58702ed4c2a40832c51758d5344201d89a"
    assert_equal reflog[0][:message], nil
    assert_equal reflog[0][:committer][:name], "foo"
    assert_equal reflog[0][:committer][:email], "foo@bar"
    assert_kind_of Time, reflog[0][:committer][:time]

    assert_equal reflog[1][:id_old], "36060c58702ed4c2a40832c51758d5344201d89a"
    assert_equal reflog[1][:id_new], "36060c58702ed4c2a40832c51758d5344201d89a"
    assert_equal reflog[1][:message], "commit: bla bla"
    assert_equal reflog[1][:committer][:name], "foo"
    assert_equal reflog[1][:committer][:email], "foo@bar"
    assert_kind_of Time, reflog[1][:committer][:time]
  end
end

