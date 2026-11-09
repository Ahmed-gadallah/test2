CREATE TABLE "branches" (
	"branch_id" integer PRIMARY KEY NOT NULL,
	"name_ar" text NOT NULL,
	"name_en" text,
	"city" text NOT NULL,
	"district" text,
	"address_ar" text NOT NULL,
	"address_en" text,
	"phone" text,
	"maps_url" text,
	"notes" text,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "branches_active_city_idx" ON "branches" USING btree ("active","city");