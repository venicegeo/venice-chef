# encoding: UTF-8
# Cookbook Name:: apache_kafka
# Attribute:: default
#

default["apache_kafka"]["version"] = "0.9.0.1"
default["apache_kafka"]["scala_version"] = "2.10"
default["apache_kafka"]["mirror"] = "http://www.us.apache.org/dist/kafka"
default["apache_kafka"]["checksum"]["0.9.0.1"] = "7f3900586c5e78d4f5f6cbf52b7cd6c02c18816ce3128c323fd53858abcf0fa1"
default["apache_kafka"]["service_style"] = "runit"

default["apache_kafka"]["conf"]["server"] = {
  "file" => "server.properties",
  "entries" => {
    "auto.create.topics.enable" => "true",
    "default.replication.factor" => "2",
    "broker.id" => "-1",
    "num.partitions" => "3",
    "listeners" => "PLAINTEXT://:9092",
    "advertised.listeners" => "PLAINTEXT://:9092",
    "advertised.port" => "9092",
    "delete.topic.enable" => "true"
  }
}
