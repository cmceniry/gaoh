require 'openssl'


plain_data = "Hello world, how are you? Are you encrypted like you should be?  I hope you are."

# Encrypt with 256 bit AES with CBC
cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
cipher.encrypt # We are encypting
# The OpenSSL library will generate random keys and IVs
cipher.key = random_key = cipher.random_key
#cipher.iv = random_iv = cipher.random_iv

encrypted_data = cipher.update(plain_data) # Encrypt the data.
encrypted_data << cipher.final



decipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
decipher.decrypt
decipher.key = random_key
#decipher.iv = random_iv

decrypted_data = decipher.update(encrypted_data)
decrypted_data << decipher.final
