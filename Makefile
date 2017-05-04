OCAMLBUILD=ocamlbuild -classic-display \
                      -pkgs lwt,lwt.unix,unix,str,graphics
TARGET=native
DIR=use_examples/

int_generator:
	$(OCAMLBUILD) $(DIR)int_generator.$(TARGET)

int_generator_net:
	$(OCAMLBUILD) $(DIR)int_generator_network.$(TARGET)

put_get:
	$(OCAMLBUILD) $(DIR)put_get_test.$(TARGET)

sift:
	$(OCAMLBUILD) $(DIR)SIFT.$(TARGET)

sift_net:
	$(OCAMLBUILD) $(DIR)SIFT_network.$(TARGET)

mandel:
	$(OCAMLBUILD) $(DIR)Mandelbrot.$(TARGET)

pong:
	$(OCAMLBUILD) $(DIR)pong_dist.$(TARGET)

clean:
	$(OCAMLBUILD) -clean

realclean: clean
	rm -f *~

cleanall: realclean
