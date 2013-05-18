# Helper methods
class Hash
  def reverse_as_list
    result = Hash.new []
    self.each_pair do |k, v|
      vv = result[v]
      vv << k
      result[v] = vv
    end

    result
  end
end
