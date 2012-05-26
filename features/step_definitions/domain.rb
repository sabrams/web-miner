# Create simple domain classes

ATTRIBUTES = Transform /with attributes (.*)/ do |attribute_list|
  names = attribute_list.scan(/\w+/)
end

Given(/^a domain class "([^\"]*)" (#{ATTRIBUTES})$/) do |name, attributes|
  create_domain_class(name, attributes)
end

def create_domain_class(class_name, attrs)
  
  clazz = Class.new do
    def self.define_attribute(attribute)
      self.send :attr_accessor, attribute
      #self.send old_equiv = self.instance_method(:==)
      #self.send(:define_method, :==) do |object|
      #  old_equiv.bind(self).call(object) && attribute == object.attribute
      #end
    end
  end
  Object.const_set class_name, clazz
  attrs.each { |att| clazz.define_attribute(att)}
end
