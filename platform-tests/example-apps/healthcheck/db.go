package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
)

type MySQL struct {
	Host string `json:"host"`
	Port string `json:"port"`
	Name string `json:"name"`
	User string `json:"username"`
	Pass string `json:"password"`
}

type services struct {
	MySQL []MySQL `json:"mysql"`
}

func dbHandler(w http.ResponseWriter, r *http.Request) {
	ssl := r.FormValue("ssl") != "false"
	service := r.FormValue("service")

	err := testDBConnection(ssl, service)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJson(w, map[string]interface{}{
		"success": true,
	})
}

func testDBConnection(ssl bool, service string) error {
	var sslTrigger string
	var sslOn string
	var sslOff string

	if service == "" {
		service = "postgres"
	}

	dbu := os.Getenv("DATABASE_URL")

	switch service {
	case "mysql":
		sslTrigger = "tls"
		sslOn = "skip-verify"
		sslOff = "false"
		err := adaptMySQLURL(&dbu)
		if err != nil {
			return err
		}
	case "postgres":
		sslTrigger = "sslmode"
		sslOn = "verify-full"
		sslOff = "disable"
	default:
		return fmt.Errorf("unknown service: %s", service)
	}

	dbURL, err := url.Parse(dbu)
	if err != nil {
		return err
	}

	values := dbURL.Query()

	if ssl {
		values.Set(sslTrigger, sslOn)
	} else {
		values.Set(sslTrigger, sslOff)
	}

	dbURL.RawQuery = values.Encode()

	db, err := sql.Open(service, dbURL.String())
	if err != nil {
		return err
	}
	defer db.Close()

	_, err = db.Exec("CREATE TABLE foo(id integer)")
	if err != nil {
		return err
	}
	defer func() {
		db.Exec("DROP TABLE foo")
	}()

	_, err = db.Exec("INSERT INTO foo VALUES(42)")
	if err != nil {
		return err
	}

	var id int
	err = db.QueryRow("SELECT * FROM foo LIMIT 1").Scan(&id)
	if err != nil {
		return err
	}
	if id != 42 {
		return fmt.Errorf("Expected 42, got %d", id)
	}

	return nil
}

func adaptMySQLURL(dbu *string) error {
	var s = services{}
	err := json.Unmarshal([]byte(os.Getenv("DATABASE_URL")), &s)
	if err != nil {
		return err
	}

	*dbu = fmt.Sprintf("%s:%s@tcp(%s:%s)%s", s.MySQL[0].User, s.MySQL[0].Pass, s.MySQL[0].Host, s.MySQL[0].Port, s.MySQL[0].Name)

	return nil
}
