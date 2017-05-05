OCAMLBUILD=ocamlbuild -classic-display \
                      -pkgs lwt,lwt.unix,unix,str,graphics
TARGET=native
DIR=use_examples/

put_get:
	$(OCAMLBUILD) $(DIR)put_get_test.$(TARGET)

int_generator:
	$(OCAMLBUILD) $(DIR)int_generator.$(TARGET)

sift:
	$(OCAMLBUILD) $(DIR)SIFT.$(TARGET)

mandel:
	$(OCAMLBUILD) $(DIR)Mandelbrot.$(TARGET)

pong:
	$(OCAMLBUILD) $(DIR)pong_dist.$(TARGET)

kmeans:
	$(OCAMLBUILD) $(DIR)K_means.$(TARGET)

int_generator_net:
	$(OCAMLBUILD) $(DIR)int_generator_network.$(TARGET)

sift_net:
	$(OCAMLBUILD) $(DIR)SIFT_network.$(TARGET)



clean:
	$(OCAMLBUILD) -clean

realclean: clean
	rm -f *~

cleanall: realclean
