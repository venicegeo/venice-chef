package "fuse"
package "fuse-libs"

script 'easy_install pip' do
  interpreter 'bash'
  user 'root'
  group 'root'
  code <<-EOH
  easy_install pip
  EOH
end

script 'pip install yas3fs' do
  interpreter 'bash'
  user 'root'
  group 'root'
  code <<-EOH
  pip install yas3fs
  EOH
end

