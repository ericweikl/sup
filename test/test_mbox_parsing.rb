#!/usr/bin/ruby

require 'test/unit'
require 'sup'
require 'stringio'

include Redwood

class TestMBoxParsing < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_normal_headers
    h = MBox.read_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
To: Sally <sally@sally.com>
EOS

    assert_equal "Bob <bob@bob.com>", h["From"]
    assert_equal "Sally <sally@sally.com>", h["To"]
    assert_nil h["Message-Id"]
  end

  ## this is shitty behavior in retrospect, but it's built in now.
  def test_message_id_stripping
    h = MBox.read_header StringIO.new("Message-Id: <one@bob.com>\n")
    assert_equal "one@bob.com", h["Message-Id"]

    h = MBox.read_header StringIO.new("Message-Id: one@bob.com\n")
    assert_equal "one@bob.com", h["Message-Id"]
  end

  def test_multiline
    h = MBox.read_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
Subject: one two three
  four five six
To: Sally <sally@sally.com>
References: seven
  eight
Seven: Eight
EOS

    assert_equal "one two three four five six", h["Subject"]
    assert_equal "Sally <sally@sally.com>", h["To"]
    assert_equal "seven eight", h["References"]
  end

  def test_ignore_spacing
    variants = [
      "Subject:one two  three   end\n",
      "Subject:    one two  three   end\n",
      "Subject:   one two  three   end    \n",
    ]
    variants.each do |s|
      h = MBox.read_header StringIO.new(s)
      assert_equal "one two  three   end", h["Subject"]
    end
  end

  def test_message_id_ignore_spacing
    variants = [
      "Message-Id:     <one@bob.com>       \n",
      "Message-Id:      one@bob.com        \n",
      "Message-Id:<one@bob.com>       \n",
      "Message-Id:one@bob.com       \n",
    ]
    variants.each do |s|
      h = MBox.read_header StringIO.new(s)
      assert_equal "one@bob.com", h["Message-Id"]
    end
  end

  def test_blank_lines
    h = MBox.read_header StringIO.new("")
    assert_equal nil, h["Message-Id"]
  end

  def test_empty_headers
    variants = [
      "Message-Id:       \n",
      "Message-Id:\n",
    ]
    variants.each do |s|
      h = MBox.read_header StringIO.new(s)
      assert_equal "", h["Message-Id"]
    end
  end

  def test_detect_end_of_headers
    h = MBox.read_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>

To: a dear friend
EOS
  assert_equal "Bob <bob@bob.com>", h["From"]
  assert_nil h["To"]

  h = MBox.read_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
\r
To: a dear friend
EOS
  assert_equal "Bob <bob@bob.com>", h["From"]
  assert_nil h["To"]

  h = MBox.read_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
\r\n\r
To: a dear friend
EOS
  assert_equal "Bob <bob@bob.com>", h["From"]
  assert_nil h["To"]
  end

  def test_from_line_splitting
    l = MBox::Loader.new StringIO.new(<<EOS)
From sup-talk-bounces@rubyforge.org Mon Apr 27 12:56:18 2009
From: Bob <bob@bob.com>
To: a dear friend

Hello there friend. How are you?

From sea to shining sea

From bob@bob.com I get only spam.

From bob@bob.com   

From bob@bob.com

(that second one has spaces at the endj

This is the end of the email.
EOS
    offset, labels = l.next
    assert_equal 0, offset
    offset, labels = l.next
    assert_nil offset
  end

  def test_more_from_line_splitting
    l = MBox::Loader.new StringIO.new(<<EOS)
From sup-talk-bounces@rubyforge.org Mon Apr 27 12:56:18 2009
From: Bob <bob@bob.com>
To: a dear friend

Hello there friend. How are you?

From bob@bob.com Mon Apr 27 12:56:19 2009
From: Bob <bob@bob.com>
To: a dear friend

Hello again! Would you like to buy my products?
EOS
    offset, labels = l.next
    assert_not_nil offset

    offset, labels = l.next
    assert_not_nil offset

    offset, labels = l.next
    assert_nil offset
  end
end
