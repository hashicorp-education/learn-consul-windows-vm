Kind = "service-intentions"
Name = "fakeservice-backend"
Sources = [
  {
    Name   = "fakeservice-frontend"
    Action = "allow"
  }
]