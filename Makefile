OCAMLBUILD=ocamlbuild -classic-display \
					  -pkgs lwt,lwt.unix,unix
TARGET=native

example:
	$(OCAMLBUILD) example.$(TARGET)


clean:
	$(OCAMLBUILD) -clean

realclean: clean
	rm -f *~

cleanall: realclean
