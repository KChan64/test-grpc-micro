# Why raise error when i use `plugins=grpc` and `micro` simultaneously

##  Error details and my solution

### proto

```protobuf
syntax = "proto3";
option go_package = "proto";
package proto;


service Auth {
    rpc Create(User) returns (Response) {}
    rpc Get(User) returns (Response) {}
    rpc GetAll(Request) returns (Response) {}
    rpc Auth(User) returns (Token) {}
    rpc ValidateToken(Token) returns (Token) {}
}

message User {
    string id = 1;
    string name = 2;
    string company = 3;
    string email = 4;
    string password = 5;
    string token = 6;
}

message Request {}

message Response {
    User user = 1;
    repeated User users = 2;
    repeated Error errors = 3;
    Token token = 4;
}

message Token {
    string token = 1;
    bool valid = 2;
    repeated Error errors = 3;
}

message Error {
    int32 code = 1;
    string description = 2;
}

```

```protobuf
syntax = "proto3";
option go_package = "proto";
package proto;

service VesselService {
	rpc FindAvailable(Specification) returns (Response) {}
	rpc Create(Vessel) returns (Response) {}
}

message Vessel {
	string id = 1;
	int32 capacity = 2;
	int32 max_weight = 3;
	string name = 4;
	bool available = 5;
	string owner_id = 6;
}

message Specification {
	int32 capacity = 1;
	int32 max_weight = 2;
}

message Response {
	Vessel vessel = 1;
	repeated Vessel vessels = 2;
	bool created = 3;
}
```

```protobuf
// shippy-service-consignment/proto/consignment/consignment.proto
syntax = "proto3";
option go_package = "consignment";
package consignment;

service ShippingService {
  rpc CreateConsignment(Consignment) returns (Response) {}

  // Created a new method
  rpc GetConsignments(GetRequest) returns (Response) {}
}

message Consignment {
  string id = 1;
  string description = 2;
  int32 weight = 3;
  repeated Container containers = 4;
  string vessel_id = 5;
}

message Container {
  string id = 1;
  string customer_id = 2;
  string origin = 3;
  string user_id = 4;
}

// Created a blank get request
message GetRequest {}

message Response {
  bool created = 1;
  Consignment consignment = 2;

  // Added a pluralised consignment to our generic response message
  repeated Consignment consignments = 3;
}
```

### server

```go
package main

import (

	// Import the generated protobuf code
	"errors"
	"fmt"
	"log"

	"os"

	"golang.org/x/net/context"

	userService "github.com/kcorlidy/grpc-example/microservices/proto/auth"
	pb "github.com/kcorlidy/grpc-example/microservices/proto/consignment"
	vesselProto "github.com/kcorlidy/grpc-example/microservices/proto/vessel"

	k8s "github.com/micro/examples/kubernetes/go/micro"

	"github.com/micro/go-micro"
	"github.com/micro/go-micro/metadata"
	"github.com/micro/go-micro/server"
)

const (
	defaultHost = "localhost:27017"
)

var (
	srv micro.Service
)

func main() {

	// Database host from the environment variables
	host := os.Getenv("DB_HOST")

	if host == "" {
		host = defaultHost
	}

	session, err := CreateSession(host)

	// Mgo creates a 'master' session, we need to end that session
	// before the main function closes.
	defer session.Close()

	if err != nil {

		// We're wrapping the error returned from our CreateSession
		// here to add some context to the error.
		log.Panicf("Could not connect to datastore with host %s - %v", host, err)
	}

	// Create a new service. Optionally include some options here.
	srvx := k8s.NewService(

		// This name must match the package name given in your protobuf definition
		micro.Name("shippy.consignment"),
		//micro.Version("latest"),
		//micro.WrapHandler(AuthWrapper),
	)

	vesselClient := vesselProto.NewVesselServiceClient("shippy.vessel", srvx.Client())

	// Init will parse the command line flags.
	srv.Init()

	// Register handler
	pb.RegisterConsignmentServiceHandler(srv.Server(), &service{session, vesselClient})

	// Run the server
	if err := srv.Run(); err != nil {
		fmt.Println(err)
	}
}

// AuthWrapper is a high-order function which takes a HandlerFunc
// and returns a function, which takes a context, request and response interface.
// The token is extracted from the context set in our consignment-cli, that
// token is then sent over to the user service to be validated.
// If valid, the call is passed along to the handler. If not,
// an error is returned.
func AuthWrapper(fn server.HandlerFunc) server.HandlerFunc {
	return func(ctx context.Context, req server.Request, resp interface{}) error {
		if os.Getenv("DISABLE_AUTH") == "true" {
			return fn(ctx, req, resp)
		}
		meta, ok := metadata.FromContext(ctx)
		if !ok {
			return errors.New("no auth meta-data found in request")
		}

		// Note this is now uppercase (not entirely sure why this is...)
		token := meta["Token"]
		log.Println("Authenticating with token: ", token)

		// Auth here
		// Really shouldn't be using a global here, find a better way
		// of doing this, since you can't pass it into a wrapper.
		authClient := userService.NewAuthClient("shippy.user", srv.Client())
		_, err := authClient.ValidateToken(ctx, &userService.Token{
			Token: token,
		})
		if err != nil {
			return err
		}
		err = fn(ctx, req, resp)
		return err
	}
}
```

### error

```bash
# github.com/kcorlidy/grpc-example/microservices/proto/auth
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\auth\auth.pb.go:342:7: undefined: grpc.ClientConnInterface
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\auth\auth.pb.go:346:11: undefined: grpc.SupportPackageIsVersion6
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\auth\auth.pb.go:360:5: undefined: grpc.ClientConnInterface
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\auth\auth.pb.go:363:23: undefined: grpc.ClientConnInterface
# github.com/kcorlidy/grpc-example/microservices/proto/consignment
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\consignment\consignment.pb.go:286:7: undefined: grpc.ClientConnInterface
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\consignment\consignment.pb.go:290:11: undefined: grpc.SupportPackageIsVersion6
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\consignment\consignment.pb.go:302:5: undefined: grpc.ClientConnInterface
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\consignment\consignment.pb.go:305:34: undefined: grpc.ClientConnInterface
# github.com/kcorlidy/grpc-example/microservices/proto/vessel
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\vessel\vessel.pb.go:242:7: undefined: grpc.ClientConnInterface
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\vessel\vessel.pb.go:246:11: undefined: grpc.SupportPackageIsVersion6
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\vessel\vessel.pb.go:257:5: undefined: grpc.ClientConnInterface
C:\Users\hasee\go\pkg\mod\github.com\kcorlidy\grpc-example@v0.0.0-20200609041527-60f3ef69ed75\microservices\proto\vessel\vessel.pb.go:260:32: undefined: grpc.ClientConnInterface
```

### go.mod

```go
module github.com/kcorlidy/grpc-example/microservices/server/shippy-consignment-service

go 1.14

replace github.com/kcorlidy/grpc-example/microservices/proto => C:/Users/hasee/go/src/github.com/kcorlidy/grpc-example/microservices/proto

require (
	github.com/kcorlidy/grpc-example v0.0.0-20200609041527-60f3ef69ed75
	github.com/micro/examples v0.2.0
	github.com/micro/go-micro v1.18.0
	github.com/micro/go-micro/v2 v2.8.0 // indirect
	golang.org/x/net v0.0.0-20200602114024-627f9648deb9
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

***Changed the proto file, but raising same error.***

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

