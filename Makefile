OCAMLBUILD=ocamlbuild -classic-display \
					  -pkgs lwt,lwt.unix,unix
TARGET=native

int_generator:
	$(OCAMLBUILD) int_generator.$(TARGET)

put_get:
	$(OCAMLBUILD) put_get_test.$(TARGET)

sift:
	$(OCAMLBUILD) SIFT.$(TARGET)

clean:
	$(OCAMLBUILD) -clean

realclean: clean
	rm -f *~

cleanall: realclean
