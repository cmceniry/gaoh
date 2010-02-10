


class Integer
   def prime?
     n = self.abs()
     return true if n == 2
     return false if n == 1 || n & 1 == 0

     # cf. http://betterexplained.com/articles/another-look-at-prime-numbers/ and
     # http://everything2.com/index.pl?node_id=1176369

     return false if n > 3 && n % 6 != 1 && n % 6 != 5     # added

     d = n-1
     d >>= 1 while d & 1 == 0
     20.times do                               # 20 = k from above
       a = rand(n-2) + 1
       t = d
       y = ModMath.pow(a,t,n)                  # implemented below
       while t != n-1 && y != 1 && y != n-1
         y = (y * y) % n
         t <<= 1
       end
       return false if y != n-1 && t & 1 == 0
     end
     return true
   end
end
 
module ModMath
   def ModMath.pow(base, power, mod)
     result = 1
     while power > 0
       result = (result * base) % mod if power & 1 == 1
       base = (base * base) % mod
       power >>= 1;
     end
     result
   end
end

111111235612323.upto(111111235612500) do |v|
  puts "#{v} : #{v.prime?}"
end
