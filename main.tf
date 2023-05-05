variable "aiven_api_token" {}
variable "project_name" {}
variable "service_cloud" {}
variable "service_cloud_secondary" {}
variable "service_name_prefix" {}
variable "service_plan_pg" {}
variable "ips" {
    type = list(object({
        network  = string,
        description = string
    }))
}

terraform {
  required_providers {
    aiven = {
      source = "aiven/aiven"
      version = "4.2.1"
    }
  }
}

provider "aiven" {
  api_token = var.aiven_api_token
}

###################################################
# PostgreSQL
###################################################

resource "aiven_pg" "demo-master" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_pg
  service_name            = "${var.service_name_prefix}-master"

  pg_user_config {
    pg_version            = "15"

    dynamic ip_filter_object {      
      for_each = var.ips
      content {
        network = ip_filter_object.value["network"]
        description =ip_filter_object.value["description"]
      }
    }
  }
}

resource "aiven_pg" "demo-read-replica" {
  project                 = var.project_name
  cloud_name              = var.service_cloud_secondary
  service_name            = "${var.service_name_prefix}-read-replica"
  plan                    = "startup-4"

  pg_user_config {
    service_to_fork_from = aiven_pg.demo-master.service_name
    
    pglookout {
      max_failover_replication_time_lag = 60
    }

    dynamic ip_filter_object {      
      for_each = var.ips
      content {
        network = ip_filter_object.value["network"]
        description =ip_filter_object.value["description"]
      }
    }
  }

  service_integrations {
    integration_type    = "read_replica"
    source_service_name = aiven_pg.demo-master.service_name
  }

  depends_on = [
    aiven_pg.demo-master
  ]
}

resource "aiven_service_integration" "pg-readreplica" {
  project                  = var.project_name
  integration_type         = "read_replica"
  source_service_name      = aiven_pg.demo-master.service_name
  destination_service_name = aiven_pg.demo-read-replica.service_name
}
