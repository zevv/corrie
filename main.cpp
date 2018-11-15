
void init();
void rec();
void calc();
void draw();
void events();

int main(int argc, char **argv)
{
	init();

	for(;;) {
		events();
		//calc();
		//draw();
	}

	return 0;
}

