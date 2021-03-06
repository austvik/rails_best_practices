# encoding: utf-8
require 'rails_best_practices/reviews/review'

module RailsBestPractices
  module Reviews
    # Make sure to use observer (sorry we only check the mailer deliver now).
    #
    # See the best practice details here http://rails-bestpractices.com/posts/19-use-observer.
    #
    # TODO: we need a better solution, any suggestion?
    #
    # Implementation:
    #
    # Review process:
    #   check all call nodes to see if they are callback definitions, like after_create, before_destroy,
    #   if so, remember the callback methods.
    #
    #   check all method define nodes to see
    #   if the method is a callback method,
    #   and there is a mailer deliver call,
    #   then the method should be replaced by using observer.
    class UseObserverReview < Review
      def url
        "http://rails-bestpractices.com/posts/19-use-observer"
      end

      def interesting_nodes
        [:defn, :call]
      end

      def interesting_files
        MODEL_FILES
      end

      def initialize
        super
        @callbacks = []
      end

      # check a call node.
      #
      # if it is a callback definition, like
      #
      #     after_create :send_create_notification
      #     before_destroy :send_destroy_notification
      #
      # then remember its callback methods (:send_create_notification).
      def start_call(node)
        remember_callback(node)
      end

      # check a method define node in prepare process.
      #
      # if it is callback method,
      # and there is a actionmailer deliver call in the method define node,
      # then it should be replaced by using observer.
      def start_defn(node)
        if callback_method?(node) and deliver_mailer?(node)
          add_error "use observer"
        end
      end

      private
        # check a call node, if it is a callback definition, such as after_create, before_create, like
        #
        #     s(:call, nil, :after_create,
        #       s(:arglist, s(:lit, :send_create_notification))
        #     )
        #
        # then save the callback methods in @callbacks
        #
        #     @callbacks => [:send_create_notification]
        def remember_callback(node)
          if node.message.to_s =~ /^after_|^before_/
            node.arguments[1..-1].each do |argument|
              # ignore callback like after_create Comment.new
              @callbacks << argument.to_s if :lit == argument.node_type
            end
          end
        end

        # check a defn node to see if the method name exists in the @callbacks.
        def callback_method?(node)
          @callbacks.find { |callback| equal?(callback, node.method_name) }
        end

        # check a defn node to see if it contains a actionmailer deliver call.
        #
        # for rails2
        #
        # if the message of call node is deliver_xxx,
        # and the subject of the call node exists in @callbacks, like
        #
        #     s(:call, s(:const, :ProjectMailer), :deliver_notification,
        #       s(:arglist, s(:self), s(:lvar, :member))
        #     )
        #
        # for rails3
        #
        # if the message of call node is deliver,
        # and the subject of the call node is with subject node who exists in @callbacks, like
        #
        #     s(:call,
        #       s(:call, s(:const, :ProjectMailer), :notification,
        #         s(:arglist, s(:self), s(:lvar, :member))
        #       ),
        #       :deliver,
        #       s(:arglist)
        #     )
        #
        # then the call node is actionmailer deliver call.
        def deliver_mailer?(node)
          node.grep_nodes(:node_type => :call) do |child_node|
            # rails2 actionmailer deliver
            return true if child_node.message.to_s =~ /^deliver_/ && mailer_names.include?(child_node.subject.to_s)
            # rails3 actionmailer deliver
            return true if :deliver == child_node.message && mailer_names.include?(child_node.subject.subject.to_s)
          end
          false
        end

        def mailer_names
          @mailer_names ||= Prepares.mailer_names.collect(&:to_s)
        end
    end
  end
end
