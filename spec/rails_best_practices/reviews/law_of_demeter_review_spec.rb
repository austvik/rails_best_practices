require 'spec_helper'

describe RailsBestPractices::Reviews::LawOfDemeterReview do

  let(:runner) {
    RailsBestPractices::Core::Runner.new(
      :prepares => RailsBestPractices::Prepares::ModelPrepare.new,
      :reviews => RailsBestPractices::Reviews::LawOfDemeterReview.new
    )
  }

  describe "belongs_to" do
    before(:each) do
      content = <<-EOF
      class Invoice < ActiveRecord::Base
        belongs_to :user
      end
      EOF
      runner.prepare('app/models/invoice.rb', content)
    end

    it "should law of demeter" do
      content = <<-EOF
      <%= @invoice.user.name %>
      <%= @invoice.user.address %>
      <%= @invoice.user.cellphone %>
      EOF
      runner.review('app/views/invoices/show.html.erb', content)
      runner.should have(3).errors
      runner.errors[0].to_s.should == "app/views/invoices/show.html.erb:1 - law of demeter"
    end

    it "should law of demeter" do
      content = <<-EOF
= @invoice.user.name
= @invoice.user.address
= @invoice.user.cellphone
      EOF
      runner.review('app/views/invoices/show.html.haml', content)
      runner.should have(3).errors
      runner.errors[0].to_s.should == "app/views/invoices/show.html.haml:1 - law of demeter"
    end

    it "should no law of demeter" do
      content = <<-EOF
      <%= @invoice.user_name %>
      <%= @invoice.user_address %>
      <%= @invoice.user_cellphone %>
      EOF
      runner.review('app/views/invoices/show.html.erb', content)
      runner.should have(0).errors
    end
  end

  describe "has_one" do
    before(:each) do
      content = <<-EOF
      class Invoice < ActiveRecord::Base
        has_one :price
      end
      EOF
      runner.prepare('app/models/invoice.rb', content)
    end

    it "should law of demeter" do
      content = <<-EOF
      <%= @invoice.price.currency %>
      <%= @invoice.price.number %>
      EOF
      runner.review('app/views/invoices/show.html.erb', content)
      runner.should have(2).errors
      runner.errors[0].to_s.should == "app/views/invoices/show.html.erb:1 - law of demeter"
    end
  end

  it "should no law of demeter with method call" do
    content = <<-EOF
    class Question < ActiveRecord::Base
      has_many :answers, :dependent => :destroy
    end
    EOF
    runner.prepare('app/models/question.rb', content)
    content = <<-EOF
    class Answer < ActiveRecord::Base
      belongs_to :question, :counter_cache => true, :touch => true
    end
    EOF
    runner.prepare('app/models/answer.rb', content)
    content = <<-EOF
    class CommentsController < ApplicationController
      def comment_url
        question_path(@answer.question)
      end
    end
    EOF
    runner.review('app/controllers/comments_controller.rb', content)
    runner.should have(0).errors
  end
end
