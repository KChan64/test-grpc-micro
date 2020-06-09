# Why raise error when i use `plugins=grpc` and `micro` simultaneously

##  Error details and my solution

### proto

```protobuf
syntax = "proto3";

package go.micro.srv.greeter;

service Say {
	rpc Hello(Request) returns (Response) {}
}

message Request {
	string name = 1;
}

message Response {
	string msg = 1;
}
```

### server

```go
package main

import (
	"log"
	"time"

	hello "github.com/kcorlidy/test-grpc×micro/grpc-errorone/greeter/srv/proto/hello"
	"github.com/micro/go-micro"
	"github.com/micro/go-micro/service/grpc"

	"context"
)

type Say struct{}

func (s *Say) Hello(ctx context.Context, req *hello.Request, rsp *hello.Response) error {
	log.Print("Received Say.Hello request")
	rsp.Msg = "Hello " + req.Name
	return nil
}

func main() {
	service := grpc.NewService(
		micro.Name("go.micro.srv.greeter"),
		micro.RegisterTTL(time.Second*30),
		micro.RegisterInterval(time.Second*10),
	)

	// optionally setup command line usage
	service.Init()

	// Register Handlers
	hello.RegisterSayHandler(service.Server(), new(Say))

	// Run server
	if err := service.Run(); err != nil {
		log.Fatal(err)
	}
}
```

### error

```bash
# github.com/coreos/etcd/clientv3/balancer/resolver/endpoint
C:\Users\hasee\go\pkg\mod\github.com\coreos\etcd@v3.3.18+incompatible\clientv3\balancer\resolver\endpoint\endpoint.go:114:78: undefined: resolver.BuildOption
C:\Users\hasee\go\pkg\mod\github.com\coreos\etcd@v3.3.18+incompatible\clientv3\balancer\resolver\endpoint\endpoint.go:182:31: undefined: resolver.ResolveNowOption
# github.com/coreos/etcd/clientv3/balancer/picker
C:\Users\hasee\go\pkg\mod\github.com\coreos\etcd@v3.3.18+incompatible\clientv3\balancer\picker\err.go:37:44: undefined: balancer.PickOptions
C:\Users\hasee\go\pkg\mod\github.com\coreos\etcd@v3.3.18+incompatible\clientv3\balancer\picker\roundrobin_balanced.go:55:54: undefined: balancer.PickOptions
```

### go.mod

```go
module github.com/kcorlidy/test-grpc×micro/grpc-errorone

go 1.14

require (
	github.com/golang/glog v0.0.0-20160126235308-23def4e6c14b
	github.com/golang/protobuf v1.4.2
	github.com/grpc-ecosystem/grpc-gateway v1.14.6
	github.com/micro/examples v0.2.0
	github.com/micro/go-micro v1.18.0
	github.com/micro/go-micro/v2 v2.8.0
	golang.org/x/net v0.0.0-20200602114024-627f9648deb9
	google.golang.org/genproto v0.0.0-20200608115520-7c474a2e3482
	google.golang.org/grpc v1.29.1
)

```



## Possibility1: Something go wrong in my server code

```go
package main

import (
	"fmt"

	userService "github.com/kcorlidy/grpc-example/microservices/proto/auth"
	pb "github.com/kcorlidy/grpc-example/microservices/proto/consignment"
	vesselProto "github.com/kcorlidy/grpc-example/microservices/proto/vessel"
)

var (
	_ = userService.User{}
	_ = pb.Consignment{}
	_ = vesselProto.Vessel{}
)

func main() {
	fmt.Println("over")
}
/*
2020/06/09 14:56:17 WARNING: proto: message proto.Response is already registered
A future release will panic on registration conflicts. See:
https://developers.google.com/protocol-buffers/docs/reference/go/faq#namespace-conflict

2020/06/09 14:56:17 WARNING: proto: file "vessel/vessel.proto" has a name conflict over proto.Response
A future release will panic on registration conflicts. See:
https://developers.google.com/protocol-buffers/docs/reference/go/faq#namespace-conflict

over
*/
```

Just WARNING.

## Possibility2: Proto content and package conflict - The Cause

Available list

- [x] `plugins.grpc × micro`
- [x] `plugins.grpc × grpc-gateway` Recommend
- [x] `plugins.grpc × mirco × grpc-gateway`

### Difference between grpc and mirco

> Go-micro makes use of the Go interface for it’s abstractions. Because of this the underlying implementation can be swapped out. Default go-micro uses HTTP for communication
>
> Go-GRPC is a simple wrapper around go-micro and the grpc plugins for the client and server.

### `plugins.grpc × mirco × grpc-gateway` - is work if you dependency is right

Be careful. Dont use `plugins=grpc`. Because it will use grpc server and mirco is incompatible to grpc version that latter than `v1.26.0`. So i dont recommend `grpc × micro`. 2020.6.9

```go
// Edit your `pb.micro.go`, just re move `v2`. So you can load correctly.
import (
	context "context"
	api "github.com/micro/go-micro/api"
	client "github.com/micro/go-micro/client"
	server "github.com/micro/go-micro/server"
)
```

```protobuf
syntax = "proto3";

package go.micro.srv.greeter;

service Say {
	rpc Hello(Request) returns (Response) {}
}

message Request {
	string name = 1;
}

message Response {
	string msg = 1;
}
```

```go
// grpc x micro
package main

import (
	"log"
	"time"

	hello "github.com/kcorlidy/test/grpc/greeter/srv/proto/hello"
	"github.com/micro/go-micro"
	"github.com/micro/go-micro/service/grpc"

	"context"
)

type Say struct{}

func (s *Say) Hello(ctx context.Context, req *hello.Request, rsp *hello.Response) error {
	log.Print("Received Say.Hello request")
	rsp.Msg = "Hello " + req.Name
	return nil
}

func main() {
	service := grpc.NewService(
		micro.Name("go.micro.srv.greeter"),
		micro.RegisterTTL(time.Second*30),
		micro.RegisterInterval(time.Second*10),
	)

	// optionally setup command line usage
	service.Init()

	// Register Handlers
	hello.RegisterSayHandler(service.Server(), new(Say))

	// Run server
	if err := service.Run(); err != nil {
		log.Fatal(err)
	}
}
// grpc-gateway
package main

import (
	"flag"
	"net/http"

	"context"
	"github.com/golang/glog"
	"github.com/grpc-ecosystem/grpc-gateway/runtime"
	"google.golang.org/grpc"

	hello "github.com/kcorlidy/test/grpc/gateway/proto/hello"
)

var (
	// the go.micro.srv.greeter address
	endpoint = flag.String("endpoint", "localhost:9090", "go.micro.srv.greeter address")
)

func run() error {
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	mux := runtime.NewServeMux()
	opts := []grpc.DialOption{grpc.WithInsecure()}

	err := hello.RegisterSayHandlerFromEndpoint(ctx, mux, *endpoint, opts)
	if err != nil {
		return err
	}

	return http.ListenAndServe(":8080", mux)
}

func main() {
	flag.Parse()

	defer glog.Flush()

	if err := run(); err != nil {
		glog.Fatal(err)
	}
}

```

```
module github.com/kcorlidy/test/grpc

go 1.14

require (
	github.com/golang/glog v0.0.0-20160126235308-23def4e6c14b
	github.com/golang/protobuf v1.4.0
	github.com/grpc-ecosystem/grpc-gateway v1.9.5
	github.com/micro/examples v0.2.0
	github.com/micro/go-micro v1.7.1-0.20190711204633-5157241c88e0
	github.com/micro/go-micro/v2 v2.8.0
	golang.org/x/net v0.0.0-20200520182314-0ba52f642ac2
	google.golang.org/genproto v0.0.0-20191216164720-4f79533eabd1
	google.golang.org/grpc v1.26.0
)
```

