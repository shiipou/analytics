terraform {
  required_providers {
    checkly = {
      source  = "checkly/checkly"
      version = "~> 1.0"
    }
  }

  cloud {
    workspaces {
      name = "checkly-e2e"
    }
  }

}

variable "checkly_api_key" {
  sensitive = true
}

variable "checkly_account_id" {
  sensitive = true
}

variable "checkly_alert_channel_pagerduty_service_key" {
  sensitive = true
}

provider "checkly" {
  api_key    = var.checkly_api_key
  account_id = var.checkly_account_id
}

resource "checkly_check" "plausible-io-api-health" {
  name         = "Check plausible.io/api/health"
  type         = "API"
  activated    = true
  frequency    = 1
  double_check = true

  group_id = checkly_check_group.reachability.id

  request {
    url              = "https://plausible.io/api/health"
    follow_redirects = false
    skip_ssl         = false
    assertion {
      source     = "JSON_BODY"
      property   = "$.clickhouse"
      comparison = "EQUALS"
      target     = "ok"
    }
    assertion {
      source     = "JSON_BODY"
      property   = "$.postgres"
      comparison = "EQUALS"
      target     = "ok"
    }
    assertion {
      source     = "JSON_BODY"
      property   = "$.sites_cache"
      comparison = "EQUALS"
      target     = "ok"
    }
  }
}

resource "checkly_check" "plausible-io-lb-health" {
  name         = "Check one.lb.plausible.io/api/health"
  type         = "API"
  activated    = true
  frequency    = 1
  double_check = true

  group_id = checkly_check_group.reachability.id

  request {
    url              = "https://one.lb.plausible.io/api/health"
    follow_redirects = false
    skip_ssl         = false
    assertion {
      source     = "JSON_BODY"
      property   = "$.clickhouse"
      comparison = "EQUALS"
      target     = "ok"
    }
    assertion {
      source     = "JSON_BODY"
      property   = "$.postgres"
      comparison = "EQUALS"
      target     = "ok"
    }
    assertion {
      source     = "JSON_BODY"
      property   = "$.sites_cache"
      comparison = "EQUALS"
      target     = "ok"
    }
  }
}

resource "checkly_check" "plausible-io-custom-domain-server-health" {
  name         = "Check custom.plausible.io"
  type         = "API"
  activated    = true
  frequency    = 1
  double_check = true

  group_id = checkly_check_group.reachability.id

  request {
    url              = "https://custom.plausible.io"
    follow_redirects = false
    skip_ssl         = false
    assertion {
      source     = "STATUS_CODE"
      comparison = "EQUALS"
      target     = "200"
    }
  }
}

resource "checkly_check" "plausible-io-ingestion" {
  name         = "Check plausible.io/api/event"
  type         = "API"
  activated    = true
  frequency    = 1
  double_check = true
  group_id     = checkly_check_group.reachability.id

  request {
    url              = "https://plausible.io/api/event"
    follow_redirects = false
    skip_ssl         = false
    method           = "POST"
    headers = {
      User-Agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284"
    }
    body_type = "JSON"
    body      = <<EOT
      {
        "name": "pageview",
        "url": "https://internal--checkly.com/",
        "domain": "internal--checkly.com",
        "width": 1666
      }
EOT

    assertion {
      source     = "STATUS_CODE"
      comparison = "EQUALS"
      target     = 202
    }
    assertion {
      source     = "TEXT_BODY"
      comparison = "EQUALS"
      target     = "ok"
    }
    assertion {
      source     = "HEADERS"
      property   = "x-plausible-dropped"
      comparison = "IS_EMPTY"
    }
  }
}

resource "checkly_check" "plausible-io-tracker-script" {
  name         = "Check plausible.io/js/script.js"
  type         = "API"
  activated    = true
  frequency    = 1
  double_check = true

  group_id = checkly_check_group.reachability.id

  request {
    url              = "https://plausible.io/js/script.js"
    follow_redirects = false
    skip_ssl         = false
    assertion {
      source     = "STATUS_CODE"
      comparison = "EQUALS"
      target     = "200"
    }
    assertion {
      source     = "TEXT_BODY"
      comparison = "CONTAINS"
      target     = "window.plausible"
    }
  }
}

resource "checkly_check_group" "reachability" {
  name      = "Reachability probes - via automation"
  activated = true
  muted     = false
  tags      = ["terraform"]

  locations = [
    "us-east-1",
    "us-west-1",
    "eu-central-1",
    "eu-west-2",
    "eu-north-1",
    "eu-south-1",
    "ap-southeast-2"
  ]
  concurrency               = 3
  double_check              = true
  use_global_alert_settings = false

  alert_channel_subscription {
    channel_id = checkly_alert_channel.pagerduty.id
    activated  = true
  }
}

resource "checkly_alert_channel" "pagerduty" {
  pagerduty {
    account      = "plausible"
    service_key  = var.checkly_alert_channel_pagerduty_service_key
    service_name = "Plausible application"
  }
}
