resource "aws_vpc_peering_connection" "default" {
  count = var.enable_peering == true ? 1 : 0

  # acceptor
  peer_vpc_id   = data.aws_vpc.default.id

  # requestor
  vpc_id        = aws_vpc.main.id

  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

   tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-default"
    }
  )

}

