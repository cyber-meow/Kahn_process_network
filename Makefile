OCAMLBUILD=ocamlbuild -classic-display \
					  -pkgs lwt,lwt.unix,unix
TARGET=native

example:
	$(OCAMLBUILD) int_generator.$(TARGET)

sift:
	$(OCAMLBUILD) SIFT.$(TARGET)

clean:
	$(OCAMLBUILD) -clean

realclean: clean
	rm -f *~

cleanall: realclean
